import 'package:flutter_test/flutter_test.dart';
import 'package:orderix/features/ordi/data/ordi_actions.dart';

void main() {
  test('strips backtick tool call leak, keeps Turkish result', () {
    final out = OrdiActionRunner.stripLeakedToolText(
      "`add_order`(table='İÇ MEKAN 3', item='Simit', qty=1)\n\n"
      "• 'İÇ MEKAN 3' masasına 1 x Simit eklendi.",
    );
    expect(out, "• 'İÇ MEKAN 3' masasına 1 x Simit eklendi.");
  });

  test('strips bare tool call', () {
    expect(
      OrdiActionRunner.stripLeakedToolText(
        "add_order(table='X', item='Y', qty=1)",
      ),
      '',
    );
  });

  test('leaves clean confirmations alone', () {
    const clean = "• 'İÇ MEKAN 4' masasına 1 x Poğaça eklendi.";
    expect(OrdiActionRunner.stripLeakedToolText(clean), clean);
  });
}
