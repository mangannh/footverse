import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footverse/core/theme/app_theme.dart';
import 'package:footverse/core/widgets/app_tag.dart';
import 'package:footverse/core/widgets/price_text.dart';
import 'package:footverse/features/order/models/order_status.dart';
import 'package:footverse/features/order/models/order_summary_response.dart';
import 'package:footverse/features/order/models/payment_status.dart';
import 'package:footverse/features/order/widgets/order_card.dart';

OrderSummaryResponse _order({
  OrderStatus status = OrderStatus.pending,
  double total = 1250000,
}) => OrderSummaryResponse(
  id: 1,
  orderCode: 'FV-2026-0142',
  status: status,
  paymentStatus: PaymentStatus.unpaid,
  total: total,
  itemCount: 3,
  createdAt: DateTime(2026, 7, 19),
);

Future<void> _pump(
  WidgetTester tester,
  OrderSummaryResponse order, {
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: OrderCard(order: order, onTap: onTap ?? () {}),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the order code, item count, date, and status tag', (
    tester,
  ) async {
    await _pump(tester, _order());

    expect(find.text('FV-2026-0142'), findsOneWidget);
    expect(find.text('3 items · 19 Jul 2026'), findsOneWidget);
    expect(find.byType(AppTag), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('renders the total through PriceText — no raw money on screen', (
    tester,
  ) async {
    await _pump(tester, _order(total: 1250000));

    expect(find.byType(PriceText), findsOneWidget);
    expect(find.text('1250000.0'), findsNothing);
    expect(find.text('1250000'), findsNothing);
  });

  testWidgets('the whole card is one tap target', (tester) async {
    var tapped = false;
    await _pump(tester, _order(), onTap: () => tapped = true);

    await tester.tap(find.byType(OrderCard));
    expect(tapped, isTrue);
  });

  testWidgets('never shows a Cancel action on the card', (tester) async {
    await _pump(tester, _order());

    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Cancel Order'), findsNothing);
  });

  for (final entry in <(OrderStatus, String)>[
    (OrderStatus.pending, 'Pending'),
    (OrderStatus.confirmed, 'Confirmed'),
    (OrderStatus.shipping, 'Shipping'),
    (OrderStatus.delivered, 'Delivered'),
    (OrderStatus.cancelled, 'Cancelled'),
  ]) {
    testWidgets('shows the status word "${entry.$2}" for ${entry.$1}', (
      tester,
    ) async {
      await _pump(tester, _order(status: entry.$1));

      expect(find.text(entry.$2), findsOneWidget);
    });
  }
}
