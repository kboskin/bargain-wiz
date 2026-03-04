# Express Dealmaker – Reply flow architecture

Replies are produced **after** image processing. We want:
- Upload N images (eventually Firebase SDK; today mock).
- Trigger **one** generation for the whole set (not per-image).
- Get the reply back when the backend is done.

---

## 1. Model: one job per user action

- **One “request”** = user has added one or more screenshots and (optionally) keyword → we want **one** deal reply (or multiple options) for that set.
- So: **one generation job** per request, keyed by a `job_id`. Multiple attachments are the **input** to that single job, not multiple jobs.

This keeps the system simple: no need to correlate several Pub/Sub messages or merge per-image results.

---

## 2. Flow (high level)

```
[Client]                          [Backend]
   |                                    |
   | 1. Upload images (Firebase/mock)   |
   |    → image_ids[]                    |
   |                                    |
   | 2. POST /deals/generate            |
   |    { image_ids, keyword? }   ----> |
   |                              -----> 3. Create job, return job_id
   | <---- { job_id }                    |
   |                                    |
   | 4. Wait for “job done”             |
   |    (FCM / WebSocket / polling)     |
   |                                    |
   |                              [Async] Process images → one reply
   |                                    |
   | 5. Receive reply                   |
   | <---- (push or poll response)  ---- 6. Publish / store result
   |
   | 7. Show reply in UI
```

- Step 1: upload can stay per-image in the UI (progress, retry) but the **logical** unit for generation is “all uploaded image IDs”.
- Step 2: single API call with **all** `image_ids` (+ optional `keyword`) → one job.
- Step 4–6: “Reply when image processing is done” is about **how** the client gets that one job result (push vs poll).

---

## 3. Upload: Firebase (when you leave mock)

- Use **Firebase Storage** (or your CDN) to upload each file.
- Replace the current mock in `ExpressDealmakerRemoteDataSource` with real uploads; keep the same interface: `uploadScreenshot(path) → UploadScreenshotResult(id)` where `id` is the storage path/URL or a server-issued asset ID.
- Client still uploads images one-by-one and tracks state per image; the backend only cares about the **list** of IDs when starting a job.

No Pub/Sub needed for uploads; they’re plain request/response.

---

## 4. Triggering the backend (one generation)

Single endpoint, e.g.:

- **POST /v1/deals/generate** (or “lines that land” API)
  - Body: `{ "image_ids": string[], "keyword"?: string, "locale": string }` (e.g. `"en"`, `"es"` so the backend can return options in the right language).
  - Response: `{ "job_id": string }` (return immediately; processing is async).

Backend:

- Creates a job (e.g. in DB or in-memory with TTL).
- Enqueues work (Cloud Tasks, Cloud Run job, or in-process) to process **all** `image_ids` together and produce **one** reply (or a list of options).
- When done, stores the result under `job_id` and notifies the client (see below). No need for “one message per image”; it’s **one result per job**.

---

## 5. Getting the reply back (three options)

You need a way for the client to learn “job X is done; here is the reply.” Three clean options:

### A. Firebase Cloud Messaging (FCM) – recommended if you use Firebase

- Backend, when the job finishes, sends an FCM **data message** to the device (or to a user token) with payload e.g. `{ "type": "deal_reply", "job_id": "...", "options": ["...", "..."] }`.
- Client:
  - After calling `POST /deals/generate`, stores the current `job_id` and shows loading.
  - In the FCM handler, if `type == "deal_reply"` and `job_id` matches the one we’re waiting for, update UI with `options` and clear loading.
- **One** FCM message per job, so multiple attachments are already handled (they’re just the input to that one job).
- No polling; good for battery and latency. You need to register the device token with your backend when the user is in the app (or when they log in).

### B. WebSocket

- Client opens a single WebSocket per session.
- Client sends “start generation” with `image_ids` and optional `keyword`; server responds with `job_id` and then later sends “job completed” with the reply on the same connection.
- One reply message per generation; multiple attachments are again just the input to one job. Simple mental model; you need to run and scale the WebSocket server.

### C. Polling

- After `POST /deals/generate` returns `job_id`, client polls **GET /v1/deals/jobs/{job_id}** every 1–2 seconds until status is `completed` (or failed).
- Response body includes `options` when completed.
- Easiest to implement (no push infra); slightly higher latency and more requests. Still one job per request, so multiple attachments stay clean.

---

## 6. Where Pub/Sub fits (optional, backend-only)

Pub/Sub is useful **inside** the backend to decouple “image processing finished” from “notify client”:

- Worker processes images, then publishes to a topic, e.g. `deal-job-completed`, with `{ job_id, options }`.
- A subscriber (Cloud Function, Cloud Run, or app server) listens to that topic and:
  - Updates DB/cache with the result for `job_id`, and/or
  - Sends FCM (or pushes over a WebSocket) to the client that owns that job.

The **client** does not subscribe to Pub/Sub; it uses FCM, WebSocket, or polling. So “Pub/Sub” is an implementation detail of the backend, not the client–server contract. Multiple attachments don’t change this: one job → one internal event → one notification to the client.

---

## 7. Summary

| Concern              | Approach                                                                 |
|----------------------|--------------------------------------------------------------------------|
| Multiple attachments | One job per “generate” request; all image IDs in a single API call.     |
| Upload               | Firebase Storage (or mock) per image; same client UX as today.           |
| Trigger              | Single `POST /deals/generate` with `image_ids[]` and optional `keyword`.|
| Reply delivery       | Prefer **FCM**; alternatives: **WebSocket** or **polling**.              |
| Pub/Sub              | Optional **inside** backend (job done → notify client); not client API. |

This keeps the design clean with multiple attachments while leaving room to add Pub/Sub and Firebase when you’re ready.

---

## 8. Doing it with Pub/Sub (ideal backend shape)

The Flutter app **never subscribes to Pub/Sub directly**. Pub/Sub is server-to-server. The client gets the reply because a **subscriber** (triggered by Pub/Sub) either pushes via FCM or writes to Firestore so the client can listen. Below are two clean ways to “do it with Pub/Sub”.

### Important point

- **One job** = one Pub/Sub message when the job is done. Multiple attachments are the **input** to that job, so you still get exactly one message per generation.

---

### Pattern A: Pub/Sub → Subscriber → FCM → Client

Use Pub/Sub to decouple the worker that processes images from the code that notifies the device. The client only handles FCM.

**1. When the job finishes (in your worker / Cloud Run / Cloud Function):**

- Publish one message to a topic, e.g. `deal-job-completed`.

```json
{
  "job_id": "abc-123",
  "user_id": "firebase_uid_or_anon",
  "device_fcm_token": "optional_if_you_lookup_later",
  "options": ["Deal line 1", "Deal line 2", "…"],
  "status": "completed"
}
```

- If you don’t want to put the FCM token in the message, you can store it when the client calls `POST /deals/generate` (e.g. in Firestore `users/{uid}/fcmToken` or in your API DB keyed by `user_id`). Then the subscriber looks up the token from `user_id`.

**2. Create a Pub/Sub subscriber** (e.g. Cloud Function triggered by the topic, or a pull subscription in Cloud Run):

- Trigger: subscription to `deal-job-completed`.
- On message:
  - Parse `job_id`, `user_id`, `options` (and `device_fcm_token` if you put it in the message).
  - If you didn’t pass the token, load it from DB/Firestore by `user_id`.
  - Call FCM API to send a **data message** to that token with e.g. `data: { type: "deal_reply", job_id, options }`.
  - Ack the Pub/Sub message.

**3. Flutter client:**

- After calling `POST /deals/generate`, save the returned `job_id` and show loading.
- In your FCM handler (e.g. `FirebaseMessaging.onMessage` / background handler), read `data.type`, `data.job_id`, `data.options`. If `type == "deal_reply"` and `job_id` matches the one you’re waiting for, update state with `options` and clear loading.

End-to-end: **Worker → Pub/Sub → Subscriber → FCM → App**. One message per job, so multiple attachments are already covered.

---

### Pattern B: Pub/Sub → Subscriber → Firestore → Client (realtime listener)

Here the client never uses FCM for this feature; it listens to a Firestore document that the backend updates when the job is done. Pub/Sub is used to trigger that write.

**1. When the client calls `POST /deals/generate`:**

- Backend creates a job, returns `job_id`, and ensures a Firestore document exists, e.g. `deals/jobs/{job_id}` with `status: "pending"` (and optionally `user_id`). You can create this in the same API that returns `job_id`.

**2. Worker (after processing all images):**

- Does **not** write to Firestore directly. It only publishes to Pub/Sub, e.g. topic `deal-job-completed`:

```json
{
  "job_id": "abc-123",
  "options": ["Deal line 1", "Deal line 2", "…"],
  "status": "completed"
}
```

**3. Pub/Sub subscriber (e.g. Cloud Function on `deal-job-completed`):**

- On message: read `job_id`, `options`, `status`.
- Write (or update) Firestore `jobs/{job_id}` with `{ status, options, completed_at }`.
- Ack the message.

**4. Flutter client:**

- After `POST /deals/generate` returns `job_id`, subscribe to the job document (e.g. `jobs/{job_id}`):

```dart
FirebaseFirestore.instance
  .collection('jobs')
  .doc(jobId)
  .snapshots()
  .listen((snapshot) {
    final data = snapshot.data();
    if (data?['status'] == 'completed' && data?['options'] != null) {
      // update UI with data['options'], cancel listener
    }
  });
```

- When you get `status == 'completed'` and `options`, show the reply and stop listening. You can later add a TTL or delete the doc in a scheduled function to avoid clutter.

End-to-end: **Worker → Pub/Sub → Subscriber → Firestore write → Client stream**. Still one job → one Pub/Sub message → one document update → one stream event.

---

### Comparison

|                         | A: Pub/Sub → FCM → Client     | B: Pub/Sub → Firestore → Client   |
|-------------------------|--------------------------------|-----------------------------------|
| Client sees reply via   | FCM data message               | Firestore snapshot stream         |
| Works when app killed   | Yes (FCM can wake app/notify)  | No (listener is active in app)    |
| Backend needs           | FCM token per device/user     | Firestore write permission        |
| Client code             | FCM handler + match `job_id`   | Firestore listener on job doc     |

Both patterns use **one Pub/Sub message per job**; multiple attachments are only the input to that single job, so the architecture stays clean.

---

## 9. Multi-file upload: who triggers the API?

You want: **trigger calls the API → result goes into Firestore → client sees it in realtime.** With **multiple files**, the confusing part is: **when** does that trigger run?

**Key idea:** The thing that “calls the API” with the full list of image IDs should run **once per generation**, not once per file. So you must decide **who** says “all files for this request are ready.”

---

### Option A: Client triggers the API once (recommended)

**The client** is the only one that knows “I’m done uploading for this request.” So the client calls the API **once** when that moment happens. Firestore is only for the **conversation/job doc** that streams the result.

**Flow:**

1. Client uploads file 1 → get `image_id_1`, file 2 → `image_id_2`, … file N → `image_id_N` (e.g. to Storage or mock). Show progress per file in the UI.
2. **When ready** (e.g. “Get more” tapped, or auto when last upload succeeds):  
   Client calls **POST /deals/generate** **once** with  
   `{ "image_ids": ["id1", "id2", ..., "idN"], "keyword": "..." }`  
   and optionally `conversation_id`.
3. **API:** Creates one job, **creates Firestore doc** e.g. `conversations/{id}` or `jobs/{job_id}` with `{ status: "pending", image_ids, keyword }`, enqueues work (or Pub/Sub), returns `{ job_id }`.
4. **Client** subscribes to that Firestore doc (`doc(jobId).snapshots()`). Realtime “magic” = this doc later gets updated with the reply.
5. **Worker** processes all `image_ids` together, then publishes to Pub/Sub `deal-job-completed` with `{ job_id, options }`.
6. **Pub/Sub subscriber** updates the Firestore conversation doc with `{ status: "completed", options }`. Client’s listener fires → UI updates.

So: **never** trigger the API from “each file upload.” Trigger **once** from the client when you have **all** image IDs. Multi-file = client collects N IDs and sends them in that single call. One API call, one job, one Firestore doc, one Pub/Sub message when done.

---

### Option B: Batch — proceed when batch is complete (even if some uploads failed)

You use a **batch**; the server triggers the API when the batch is **complete**, and you **proceed with whatever uploads succeeded**.

**Flow:**

1. **Client** creates a batch **in Firestore only** (no REST): generate `batch_id` (e.g. UUID) in the app, then **write** a doc `batches/{batch_id}` via Firestore SDK with `{ expected_count: N, uploaded: [], status: "uploading" }`. Only **successful** uploads go into `uploaded`.

2. **Client** uploads each file to Storage under `uploads/{batch_id}/{file_id}.jpg`. On **success**: add that image_id to the batch doc’s `uploaded` array (client or Storage trigger). On **failure**: do not add to `uploaded` (you can update `failed` for UI/analytics). No need to retry for the batch to proceed.

3. **Batch complete:** The client knows “I’m done trying.” When all attempts are finished, client **only updates Firestore** (no REST): sets `batches/{batch_id}.status = "complete"`.

4. **Trigger:** When batch is complete (Firestore `onUpdate` or your API handler): read `uploaded`. If `uploaded.length >= 1`, it **publishes** to Pub/Sub topic `deal-batch-ready` with `{ batch_id, image_ids: uploaded }`. A **Pub/Sub subscriber** for `deal-batch-ready` creates the conversation doc and enqueues the worker (or publishes to `deal-job-process`). So the backend uses **Firestore trigger + Pub/Sub** only; no REST. If `uploaded.length === 0`, skip job or write “No images uploaded” in the conversation. Backend uses **Firestore trigger + Pub/Sub** only; no REST from the client.

5. Worker runs (one job for all IDs in `uploaded`), Pub/Sub → subscriber updates conversation doc → client listens for the reply.

**Summary:** Client uses **only Firestore SDK + Storage SDK** (no REST). Batch doc tracks `uploaded` (successes). Client signals batch complete by updating the batch doc. Backend: Firestore trigger to Pub/Sub deal-batch-ready, then subscriber creates conversation and enqueues worker; worker publishes to deal-job-completed; subscriber updates conversation. Proceed with successful uploads only.

---

**Recommendation:** Use Option A if the client may call one REST endpoint when ready. Use Option B when you want no REST from the client: client only Firestore and Storage; backend uses Firestore trigger and Pub/Sub to start generation and update the conversation.
