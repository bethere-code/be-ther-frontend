import 'package:dio/dio.dart';

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      placeId: json['placeId']?.toString() ?? '',
      primaryText: json['primaryText']?.toString() ?? '',
      secondaryText: json['secondaryText']?.toString() ?? '',
    );
  }
}

/// Structured venue / address saved on each event.
class StructuredPlace {
  const StructuredPlace({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.locality,
    required this.street,
    required this.area,
    required this.city,
    required this.district,
    required this.state,
    required this.country,
    required this.postalCode,
    required this.lat,
    required this.lng,
  });

  final String placeId;
  final String name;
  final String formattedAddress;
  final String locality;
  final String street;
  final String area;
  final String city;
  final String district;
  final String state;
  final String country;
  final String postalCode;
  final double lat;
  final double lng;

  String get displayLabel {
    if (name.isNotEmpty && formattedAddress.isNotEmpty) {
      if (formattedAddress.startsWith(name)) return formattedAddress;
      return '$name · $formattedAddress';
    }
    return name.isNotEmpty ? name : formattedAddress;
  }

  factory StructuredPlace.fromJson(Map<String, dynamic> json) {
    double numOf(dynamic v) {
      if (v is num) return v.toDouble();
      return double.tryParse('$v') ?? 0;
    }

    return StructuredPlace(
      placeId: json['placeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      formattedAddress: json['formattedAddress']?.toString() ?? '',
      locality: json['locality']?.toString() ?? '',
      street: json['street']?.toString() ?? '',
      area: json['area']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      postalCode: json['postalCode']?.toString() ?? '',
      lat: numOf(json['lat']),
      lng: numOf(json['lng']),
    );
  }

  Map<String, dynamic> toJson() => {
    'placeId': placeId,
    'name': name,
    'formattedAddress': formattedAddress,
    'locality': locality,
    'street': street,
    'area': area,
    'city': city,
    'district': district,
    'state': state,
    'country': country,
    'postalCode': postalCode,
    'lat': lat,
    'lng': lng,
  };
}

class PlacesRepository {
  PlacesRepository(this._dio);

  final Dio _dio;

  Future<List<PlaceSuggestion>> autocomplete({
    required String query,
    double? lat,
    double? lng,
    String? sessionToken,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/places/autocomplete',
        queryParameters: {
          'q': query,
          'lat': ?lat,
          'lng': ?lng,
          'sessionToken': ?sessionToken,
        },
      );
      final data = _extractData(res.data, 'Could not search locations');
      print('autocomplete data: $data');
      final raw = data['suggestions'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(PlaceSuggestion.fromJson)
          .where((s) => s.placeId.isNotEmpty)
          .toList();
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, 'Could not search locations'));
    }
  }

  Future<StructuredPlace> details({
    required String placeId,
    String? sessionToken,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/places/details',
        queryParameters: {'placeId': placeId, 'sessionToken': ?sessionToken},
      );
      final data = _extractData(res.data, 'Could not load place details');
      final place = data['place'];
      if (place is! Map<String, dynamic>) {
        throw Exception('Could not load place details');
      }
      return StructuredPlace.fromJson(place);
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, 'Could not load place details'));
    }
  }

  Future<StructuredPlace> reverseGeocode({
    required double lat,
    required double lng,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/places/reverse',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      final data = _extractData(res.data, 'Could not resolve current location');
      final place = data['place'];
      if (place is! Map<String, dynamic>) {
        throw Exception('Could not resolve current location');
      }
      return StructuredPlace.fromJson(place);
    } on DioException catch (e) {
      throw Exception(_apiMessage(e, 'Could not resolve current location'));
    }
  }

  Map<String, dynamic> _extractData(
    Map<String, dynamic>? body,
    String fallback,
  ) {
    if (body == null || body['ok'] != true) {
      final error = body?['error'];
      if (error is Map && error['message'] != null) {
        throw Exception(error['message'].toString());
      }
      throw Exception(fallback);
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) throw Exception(fallback);
    return data;
  }

  String _apiMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map && error['message'] != null) {
        return error['message'].toString();
      }
    }
    return fallback;
  }
}
