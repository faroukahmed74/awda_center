/// Workload credit for one completed session/appointment.
///
/// Finance always stays on [supervisorDoctorId]. Stats credit:
/// - supervisor always gets +1 as supervisor
/// - performer gets +1 as performer when set and different from supervisor
class SessionWorkloadCredit {
  const SessionWorkloadCredit({
    required this.asSupervisor,
    required this.asPerformer,
  });

  final int asSupervisor;
  final int asPerformer;

  int get total => asSupervisor + asPerformer;

  SessionWorkloadCredit operator +(SessionWorkloadCredit other) {
    return SessionWorkloadCredit(
      asSupervisor: asSupervisor + other.asSupervisor,
      asPerformer: asPerformer + other.asPerformer,
    );
  }
}

/// Applies dual credit rules for one session into [totals] keyed by person id.
void creditSessionWorkload(
  Map<String, SessionWorkloadCredit> totals, {
  required String supervisorDoctorId,
  String? performingDoctorId,
}) {
  final supervisor = supervisorDoctorId.trim();
  if (supervisor.isEmpty) return;

  final existingSup = totals[supervisor] ?? const SessionWorkloadCredit(asSupervisor: 0, asPerformer: 0);
  totals[supervisor] = SessionWorkloadCredit(
    asSupervisor: existingSup.asSupervisor + 1,
    asPerformer: existingSup.asPerformer,
  );

  final performer = performingDoctorId?.trim() ?? '';
  if (performer.isEmpty || performer == supervisor) return;

  final existingPerf = totals[performer] ?? const SessionWorkloadCredit(asSupervisor: 0, asPerformer: 0);
  totals[performer] = SessionWorkloadCredit(
    asSupervisor: existingPerf.asSupervisor,
    asPerformer: existingPerf.asPerformer + 1,
  );
}
