// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubscriptionModel _$SubscriptionModelFromJson(Map<String, dynamic> json) =>
    SubscriptionModel(
      tier: SubscriptionModel._tierFromJson(json['tier']),
      isActive: json['is_active'] as bool? ?? false,
      expiryDate: SubscriptionModel._expiryDateFromJson(json['expiry_date']),
      productId: json['product_id'] as String?,
      transactionId: json['transaction_id'] as String?,
      originalTransactionId: json['original_transaction_id'] as String?,
      platform: json['platform'] as String?,
    );

Map<String, dynamic> _$SubscriptionModelToJson(SubscriptionModel instance) =>
    <String, dynamic>{
      'tier': SubscriptionModel._tierToJson(instance.tier),
      'is_active': instance.isActive,
      'expiry_date': SubscriptionModel._expiryDateToJson(instance.expiryDate),
      'product_id': instance.productId,
      'transaction_id': instance.transactionId,
      'original_transaction_id': instance.originalTransactionId,
      'platform': instance.platform,
    };
