import 'package:flutter_test/flutter_test.dart';
import 'package:awda_center/core/session_workload.dart';

void main() {
  test('credits supervisor only when performer empty', () {
    final totals = <String, SessionWorkloadCredit>{};
    creditSessionWorkload(
      totals,
      supervisorDoctorId: 'doc-a',
      performingDoctorId: null,
    );
    expect(totals['doc-a']!.asSupervisor, 1);
    expect(totals['doc-a']!.asPerformer, 0);
    expect(totals['doc-a']!.total, 1);
    expect(totals.length, 1);
  });

  test('credits both when performer differs', () {
    final totals = <String, SessionWorkloadCredit>{};
    creditSessionWorkload(
      totals,
      supervisorDoctorId: 'doc-a',
      performingDoctorId: 'trainee-b',
    );
    expect(totals['doc-a']!.asSupervisor, 1);
    expect(totals['doc-a']!.asPerformer, 0);
    expect(totals['trainee-b']!.asSupervisor, 0);
    expect(totals['trainee-b']!.asPerformer, 1);
  });

  test('does not double-count when performer equals supervisor', () {
    final totals = <String, SessionWorkloadCredit>{};
    creditSessionWorkload(
      totals,
      supervisorDoctorId: 'doc-a',
      performingDoctorId: 'doc-a',
    );
    expect(totals['doc-a']!.asSupervisor, 1);
    expect(totals['doc-a']!.asPerformer, 0);
    expect(totals['doc-a']!.total, 1);
  });
}
