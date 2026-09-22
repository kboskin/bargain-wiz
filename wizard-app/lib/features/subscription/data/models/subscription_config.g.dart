// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubscriptionConfig _$SubscriptionConfigFromJson(Map<String, dynamic> json) =>
    SubscriptionConfig(
      products: (json['products'] as List<dynamic>)
          .map(
            (e) =>
                SubscriptionProductConfig.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );

Map<String, dynamic> _$SubscriptionConfigToJson(SubscriptionConfig instance) =>
    <String, dynamic>{'products': instance.products};

SubscriptionProductConfig _$SubscriptionProductConfigFromJson(
  Map<String, dynamic> json,
) => SubscriptionProductConfig(
  id: json['id'] as String?,
  tier: json['tier'] as String,
  productId: ProductIdConfig.fromJson(
    json['product_id'] as Map<String, dynamic>,
  ),
  title: SubscriptionProductConfig._multilocaleFromJson(json['title']),
  description: SubscriptionProductConfig._multilocaleFromJson(
    json['description'],
  ),
  features: (json['features'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  displayOrder: (json['display_order'] as num).toInt(),
);

Map<String, dynamic> _$SubscriptionProductConfigToJson(
  SubscriptionProductConfig instance,
) => <String, dynamic>{
  'id': instance.id,
  'tier': instance.tier,
  'product_id': instance.productId,
  'title': instance.title,
  'description': instance.description,
  'features': instance.features,
  'display_order': instance.displayOrder,
};

ProductIdConfig _$ProductIdConfigFromJson(Map<String, dynamic> json) =>
    ProductIdConfig(
      ios: json['ios'] as String,
      android: json['android'] as String,
    );

Map<String, dynamic> _$ProductIdConfigToJson(ProductIdConfig instance) =>
    <String, dynamic>{'ios': instance.ios, 'android': instance.android};
