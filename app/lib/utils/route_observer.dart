import 'package:flutter/widgets.dart';

/// Single RouteObserver instance used across the app to notify screens when
/// they become visible again (e.g. when popping back to a route).
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();
