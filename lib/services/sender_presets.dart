/// Quick-add sender labels for common BD MFS / banks.
class SenderPresets {
  static const items = <SenderPreset>[
    SenderPreset('bKash', ['bKash']),
    SenderPreset('Nagad', ['Nagad']),
    SenderPreset('Rocket', ['Rocket']),
    SenderPreset('Upay', ['Upay']),
    SenderPreset('NexusPay', ['16216', 'NexusPay']),
    SenderPreset('BRAC Bank', ['BRAC']),
    SenderPreset('Dutch-Bangla', ['DBBL', 'Dutch']),
    SenderPreset('City Bank', ['City']),
  ];
}

class SenderPreset {
  final String label;
  final List<String> senders;

  const SenderPreset(this.label, this.senders);
}
