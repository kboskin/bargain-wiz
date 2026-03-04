import 'package:appwizard/features/shared/presentation/bloc/base_bloc.dart';

/// Lines that land events.
abstract class LinesThatLandEvent extends BaseEvent {
  const LinesThatLandEvent();
}

/// Load daily categories (single API call, cached in bloc).
class LoadLinesThatLandRequested extends LinesThatLandEvent {
  const LoadLinesThatLandRequested();
}
