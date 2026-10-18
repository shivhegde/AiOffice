import 'package:aioffice/features/epf_consultancy/domain/epf_case.dart';
import 'package:aioffice/features/epf_consultancy/domain/epf_enums.dart';
import 'package:flutter_test/flutter_test.dart';

EpfCase _case({List<EpfService> services = const [], String otherService = ''}) => EpfCase(
      id: 'x',
      clientId: 'CL-1',
      year: 2026,
      name: 'A',
      mobile: '1',
      dateOfBirth: DateTime(1990),
      gender: Gender.male,
      services: services,
      otherService: otherService,
      stage: CaseStage.newClient,
      createdBy: 'u',
      createdByName: 'U',
      createdAt: DateTime(2026),
    );

void main() {
  test('round-trips multiple services and other-service text', () {
    final original = _case(services: const [EpfService.kycUpdate, EpfService.other], otherService: 'Nominee update');
    final map = original.toMap()..remove('updatedAt');
    final restored = EpfCase.fromMap('x', map);
    expect(restored.services, [EpfService.kycUpdate, EpfService.other]);
    expect(restored.otherService, 'Nominee update');
    expect(restored.servicesLabel, 'KYC Update, Nominee update');
  });

  test('drops other-service text when Other is not selected', () {
    final map = _case(services: const [EpfService.advance], otherService: 'stale').toMap();
    expect(map['otherService'], '');
  });

  test('reads legacy single-service records', () {
    final restored = EpfCase.fromMap('x', {'service': 'pension'});
    expect(restored.services, [EpfService.pension]);
  });

  test('Other with no text shows its label', () {
    expect(_case(services: const [EpfService.other]).servicesLabel, 'Other Services');
  });
}
