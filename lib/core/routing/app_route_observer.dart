import 'package:flutter/material.dart';

/// Shared [RouteObserver] for screens that need [RouteAware] lifecycle (e.g. feed).
final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();
