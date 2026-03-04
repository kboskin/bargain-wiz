import 'package:appwizard/domain/entities/lines_that_land_category.dart';
import 'package:appwizard/presentation/bloc/base_bloc.dart';

/// Lines that land states.
abstract class LinesThatLandState extends BaseState {
  const LinesThatLandState();
}

class LinesThatLandInitial extends LinesThatLandState {
  const LinesThatLandInitial();
}

class LinesThatLandLoading extends LinesThatLandState {
  const LinesThatLandLoading();
}

class LinesThatLandLoaded extends LinesThatLandState {
  const LinesThatLandLoaded(this.categories);
  final List<LinesThatLandCategory> categories;

  @override
  List<Object?> get props => [categories];
}

class LinesThatLandError extends LinesThatLandState {
  const LinesThatLandError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
