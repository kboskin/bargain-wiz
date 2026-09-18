import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';

/// Lines that land events.
abstract class LinesThatLandEvent extends BaseEvent {
  const LinesThatLandEvent();
}

/// App start: show the on-device copy if there is one. Never touches the network.
class LinesThatLandPrimed extends LinesThatLandEvent {
  const LinesThatLandPrimed();
}

/// The Lines tab (or sheet) became visible: show the cached copy and, when it is stale or
/// missing, refresh in the background without blocking what is on screen.
class LinesThatLandOpened extends LinesThatLandEvent {
  const LinesThatLandOpened();
}

/// Pull-to-refresh / "Try again": always calls the endpoint, keeps current content meanwhile.
class LinesThatLandRefreshRequested extends LinesThatLandEvent {
  const LinesThatLandRefreshRequested();
}
