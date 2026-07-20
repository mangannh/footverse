import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/widgets/app_error_state.dart';
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
/// leaving the destination screen to render whatever the server said. Cancel
/// requires confirmation (design/04 §4.8 — this screen is high-stakes; an
/// accidental back gesture mid-payment is costly) and, when confirmed, pops
/// without reloading, so it never pretends the payment failed or succeeded.
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
      create: (_) {
        final provider = PaymentProvider(orderRepository, orderId);
        // Fire-and-forget: the failure is already fully captured in the
        // provider's own status/error (what the UI renders from) — this
        // silences the otherwise-unhandled Future rejection without
        // changing anything observable.
        unawaited(provider.requestPaymentUrl().catchError((_) {}));
        return provider;
      },
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

  /// Confirms before leaving the payment flow — an accidental tap or back
  /// gesture mid-payment is costly (design/04 §4.8). Never renders a payment
  /// outcome itself: confirming simply pops, leaving the order exactly as the
  /// server last reported it.
  Future<void> _confirmCancel(BuildContext context) async {
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel payment?'),
        content: const Text(
          'Your order will remain unpaid. You can try again later from '
          'your order details.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep paying'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel payment'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      router.pop();
    }
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
            // Guard against an empty prefix (e.g. VNPAY_RETURN_URL_PREFIX not
            // supplied via --dart-define): every URL.startsWith('') is true in
            // Dart, which would otherwise treat the very first load of the
            // real VNPay payment page as the gateway's return and block it.
            final String returnUrlPrefix = AppConfig.vnpayReturnUrlPrefix;
            if (returnUrlPrefix.isNotEmpty &&
                request.url.startsWith(returnUrlPrefix)) {
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
            onPressed: () => _confirmCancel(context),
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
        return AppErrorState(
          message: provider.error?.message ?? 'Unable to start payment',
          onRetry: provider.requestPaymentUrl,
        );
      }
      // The one legitimate full-screen spinner exception (design/03 §21):
      // there is no known shape to skeleton before the gateway URL exists.
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: <Widget>[
        WebViewWidget(controller: _controller!),
        // The loading overlay while the gateway's own page navigates — never
        // a partial or optimistic payment status, just a neutral wait
        // indicator over the page that is mid-navigation.
        if (_pageLoading) const _LoadingOverlay(),
      ],
    );
  }
}

/// The loading overlay shown while the WebView navigates between the
/// gateway's own pages — a dimmed scrim from the theme, not a hardcoded
/// colour (design/02 §2.3).
class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  static const double _scrimOpacity = 0.6;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: ColoredBox(
        color: colorScheme.surface.withValues(alpha: _scrimOpacity),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
