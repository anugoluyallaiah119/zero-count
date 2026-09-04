import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config.dart';

class Sponsor {
  const Sponsor({
    required this.id,
    required this.name,
    this.logoUrl,
    this.siteUrl,
  });

  final String id;
  final String name;
  final String? logoUrl;
  final String? siteUrl;

  factory Sponsor.fromJson(Map<String, dynamic> j) => Sponsor(
        id: j['id'] as String,
        name: j['name'] as String,
        logoUrl: j['logo_url'] as String?,
        siteUrl: j['site_url'] as String?,
      );
}

class SponsorRepository {
  const SponsorRepository(this._dio);
  final Dio _dio;

  Future<List<Sponsor>> list() async {
    final res = await _dio.get<List<dynamic>>('/api/contests/sponsors');
    return res.data!
        .map((e) => Sponsor.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final sponsorRepositoryProvider = Provider<SponsorRepository>(
  (ref) => SponsorRepository(ref.watch(dioProvider)),
);

final sponsorsProvider = FutureProvider<List<Sponsor>>((ref) {
  return ref.watch(sponsorRepositoryProvider).list();
});
