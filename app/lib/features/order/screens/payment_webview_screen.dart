import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/app_exception.dart';
import '../providers/payment_provider.dart';
import '../repositories/order_repository.dart';

/// Hosts the VNPay sandbox payment page and detects the gateway's return
/// (sprint-13-plan Task 10, Design Notes 1–2).
///
/// It creates the screen-scoped [PaymentProvider] and requests the payment URL
/// on mount. Once loaded, the gateway's own page is shown in a
/// `webview_flutter` `WebViewWidget` — this screen builds no payment UI of its
/// own. It watches every navigation for [AppConfig.vnpayReturnUrlPrefix]; on a
/// match it **never reads the URL's query string or infers an outcome** — it
/// only reloads the order through [PaymentProvider.reloadOrder] and pops back,
/// leaving the destination screen to render whatever the server said. An
/// explicit Cancel action pops immediately without reloading, so it never
/// pretends the payment failed or succeeded.
class PaymentWebViewScreen extends StatelessWidget {
  const PaymentWebViewScreen({
    super.key,
    required this.orderId,
    required this.orderRepository,
  });

  final int orderId;
  final OrderRepository orderRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PaymentProvider>(
      create: (_) =>
          PaymentProvider(orderRepository, orderId)..requestPaymentUrl(),
      child: const _PaymentWebViewView(),
    );
  }
}

class _PaymentWebViewView extends StatefulWidget {
  const _PaymentWebViewView();

  @override
  State<_PaymentWebViewView> createState() => _PaymentWebViewViewState();
}

class _PaymentWebViewViewState extends State<_PaymentWebViewView> {
  WebViewController? _controller;
  bool _pageLoading = true;
  bool _returning = false;

  void _handleReturnDetected() {
    if (_returning) {
      return;
    }
    _returning = true;
    final provider = context.read<PaymentProvider>();
    final router = GoRouter.of(context);
    unawaited(_finishReturn(provider, router));
  }

  Future<void> _finishReturn(PaymentProvider provider, GoRouter router) async {
    try {
      await provider.reloadOrder();
    } on AppException {
      // The flow still ends here; the destination screen's own load/retry
      // surfaces any further error to the user — this screen hosts no error
      // UI of its own beyond the initial URL request.
    }
    router.pop();
  }

  void _ensureController(String paymentUrl) {
    if (_controller != null) {
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _pageLoading = true),
          onPageFinished: (_) => setState(() => _pageLoading = false),
          onNavigationRequest: (request) {
            if (request.url.startsWith(AppConfig.vnpayReturnUrlPrefix)) {
              _handleReturnDetected();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaymentProvider>();
    final paymentUrl = provider.paymentUrl?.paymentUrl;
    if (paymentUrl != null) {
      _ensureController(paymentUrl);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        actions: <Widget>[
          TextButton(
            onPressed: () => GoRouter.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(provider)),
    );
  }

  Widget _buildBody(PaymentProvider provider) {
    if (_controller == null) {
      if (provider.status == PaymentFlowStatus.error) {
        return _ErrorView(
          message: provider.error?.message ?? 'Unable to start payment',
          onClose: () => GoRouter.of(context).pop(),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: <Widget>[
        WebViewWidget(controller: _controller!),
        if (_pageLoading) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

/// The full-screen error state shown only when the initial payment-URL
/// request fails (flutter-guidelines §Error Handling); it renders the
/// enveloped message (e.g. `PAYMENT_NOT_APPLICABLE`) exactly as delivered.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onClose, child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}
