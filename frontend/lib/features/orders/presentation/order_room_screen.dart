import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:forui/forui.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../models/order_model.dart';
import '../models/order_room_models.dart';
import '../../auth/models/user_model.dart';
import '../../payments/providers/wallet_provider.dart';

class OrderRoomScreen extends ConsumerStatefulWidget {
  final int orderId;
  final Order? initialOrder;

  const OrderRoomScreen({super.key, required this.orderId, this.initialOrder});

  @override
  ConsumerState<OrderRoomScreen> createState() => _OrderRoomScreenState();
}

class _OrderRoomScreenState extends ConsumerState<OrderRoomScreen>
    with SingleTickerProviderStateMixin {
  final _chatController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _itemQtyController = TextEditingController(text: '1');
  final _itemPriceController = TextEditingController();
  final _itemNotesController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  late final TabController _tabController;
  late final Razorpay _razorpay;

  WebSocketChannel? _chatChannel;
  StreamSubscription? _chatSubscription;

  Order? _order;
  List<OrderParticipantModel> _participants = [];
  List<OrderItemModel> _items = [];
  List<OrderChatMessageModel> _messages = [];

  bool _isLoading = true;
  bool _isJoining = false;
  bool _isSubmittingCart = false;
  bool _isAddingItem = false;
  bool _isPaying = false;
  Timer? _paymentFlowTimeout;
  int? _activeReviewItemId;
  int? _pendingPaymentTransactionId;
  List<OrderItemModel> _managerQueue = [];
  String? _myOtp;
  bool _isLoadingOtp = false;

  void _logPayment(String message, [Object? extra]) {
    final suffix = extra == null ? '' : ' | $extra';
    debugPrint('[CartBuddyPayment][order:${widget.orderId}] $message$suffix');
  }

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _tabController = TabController(length: 3, vsync: this);
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWalletSelected);
    unawaited(_loadRoom());
    unawaited(_connectChat());
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _chatChannel?.sink.close();
    _paymentFlowTimeout?.cancel();
    _razorpay.clear();
    _tabController.dispose();
    _chatController.dispose();
    _itemNameController.dispose();
    _itemQtyController.dispose();
    _itemPriceController.dispose();
    _itemNotesController.dispose();
    super.dispose();
  }

  User? get _currentUser => ref.read(authStateProvider).user;

  OrderParticipantModel? get _myParticipant {
    final userId = _currentUser?.id;
    if (userId == null) return null;
    for (final participant in _participants) {
      if (participant.userId == userId) return participant;
    }
    return null;
  }

  bool get _isManager {
    final order = _order;
    if (order == null) return false;
    return order.canManage;
  }

  List<OrderItemModel> get _myItems {
    final userId = _currentUser?.id;
    if (userId == null) return const [];
    return _items.where((item) => item.participantUserId == userId).toList();
  }

  Future<void> _loadRoom() async {
    try {
      final service = ref.read(orderServiceProvider);
      final results = await Future.wait<dynamic>([
        service.getOrder(widget.orderId),
        service.getParticipants(widget.orderId),
        service.getItems(widget.orderId),
        service.getMessages(widget.orderId),
      ]);

      if (!mounted) return;
      setState(() {
        _order = results[0] as Order;
        _participants = results[1] as List<OrderParticipantModel>;
        _items = results[2] as List<OrderItemModel>;
        _messages = results[3] as List<OrderChatMessageModel>;
        _managerQueue = _items.where((item) => item.status == 'SUBMITTED').toList();
        _isLoading = false;
      });
      if (_order?.status == 'ARRIVED') {
        _loadMyOtp();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showToast('Could not load order room', e.toString());
    }
  }

  Future<void> _loadMyOtp() async {
    if (_myParticipant == null || _myParticipant!.role == 'CREATOR') return;
    setState(() => _isLoadingOtp = true);
    try {
      final data = await ref.read(orderServiceProvider).getMyOtp(widget.orderId);
      setState(() {
        _myOtp = data['otp']?.toString();
        _isLoadingOtp = false;
      });
    } catch (e) {
      setState(() => _isLoadingOtp = false);
    }
  }

  Future<void> _verifyParticipantOtp(int participantId, String otp) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(orderServiceProvider)
          .verifyOtp(widget.orderId, participantId, otp);
      
      // Refresh wallet for host
      ref.invalidate(walletBalanceProvider);
      
      await _loadRoom();
      if (!mounted) return;
      _showToast('OTP Verified', 'Participant handoff successful. Funds released to your wallet.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showToast('Verification Failed', e.toString());
    }
  }

  Future<void> _connectChat() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) return;

    final service = ref.read(orderServiceProvider);
    final baseUrl = service.baseUrl.replaceAll(RegExp(r'/$'), '');
    final wsBase = baseUrl.replaceFirst(
      RegExp(r'^http'),
      baseUrl.startsWith('https') ? 'wss' : 'ws',
    );
    final wsUrl = '$wsBase/ws/chats/orders/${widget.orderId}/?token=$token';

    try {
      await _chatSubscription?.cancel();
      await _chatChannel?.sink.close();

      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await channel.ready;
      final subscription = channel.stream.listen(
        _handleSocketPayload,
        onError: (error, stackTrace) {
          if (!mounted) return;
          setState(() {
            _chatChannel = null;
            _chatSubscription = null;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _chatChannel = null;
            _chatSubscription = null;
          });
        },
      );

      if (!mounted) {
        await subscription.cancel();
        await channel.sink.close();
        return;
      }

      setState(() {
        _chatChannel = channel;
        _chatSubscription = subscription;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _chatChannel = null;
        _chatSubscription = null;
      });
    }
  }

  void _handleSocketPayload(dynamic rawEvent) {
    try {
      final payload = jsonDecode(rawEvent.toString()) as Map<String, dynamic>;
      if (payload['type'] == 'chat.message' && payload['data'] is Map) {
        final message = OrderChatMessageModel.fromJson(
          Map<String, dynamic>.from(payload['data'] as Map),
        );
        if (!mounted) return;
        setState(() {
          final exists = _messages.any((entry) => entry.id == message.id);
          if (!exists) {
            _messages = [..._messages, message];
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _joinOrder() async {
    setState(() => _isJoining = true);
    try {
      await ref.read(orderServiceProvider).joinOrder(widget.orderId);
      await _loadRoom();
      if (!mounted) return;
      _showToast('Joined order', 'You can now add items and join the chat.');
    } catch (e) {
      if (!mounted) return;
      _showToast('Could not join order', e.toString());
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;

    _chatController.clear();
    try {
      final channel = _chatChannel;
      if (channel != null) {
        channel.sink.add(jsonEncode({'message': message}));
      } else {
        final sent = await ref
            .read(orderServiceProvider)
            .sendMessage(widget.orderId, message);
        if (!mounted) return;
        setState(() {
          _messages = [..._messages, sent];
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showToast('Could not send message', e.toString());
    }
  }

  Future<void> _addItem() async {
    final name = _itemNameController.text.trim();
    final quantity = int.tryParse(_itemQtyController.text.trim()) ?? 0;
    final price = double.tryParse(_itemPriceController.text.trim()) ?? 0;

    if (name.isEmpty || quantity <= 0 || price <= 0) {
      _showToast(
        'Incomplete item',
        'Enter a valid item name, quantity, and price.',
      );
      return;
    }

    setState(() => _isAddingItem = true);
    try {
      await ref
          .read(orderServiceProvider)
          .addItem(
            orderId: widget.orderId,
            name: name,
            quantity: quantity,
            unitPrice: price,
            specialInstructions: _itemNotesController.text.trim(),
          );
      _itemNameController.clear();
      _itemQtyController.text = '1';
      _itemPriceController.clear();
      _itemNotesController.clear();
      await _loadRoom();
      if (!mounted) return;
      _showToast('Item added', 'Your item is in draft until you submit it.');
    } catch (e) {
      if (!mounted) return;
      _showToast('Could not add item', e.toString());
    } finally {
      if (mounted) {
        setState(() => _isAddingItem = false);
      }
    }
  }

  Future<void> _submitCart() async {
    setState(() => _isSubmittingCart = true);
    try {
      await ref.read(orderServiceProvider).submitCart(widget.orderId);
      await _loadRoom();
      if (!mounted) return;
      _showToast(
        'Cart submitted',
        'The order manager can now approve or reject your items.',
      );
    } catch (e) {
      if (!mounted) return;
      _showToast('Could not submit cart', e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmittingCart = false);
      }
    }
  }

  Future<void> _updateOrderStatus(String status, {String reason = ''}) async {
    setState(() => _isLoading = true);
    try {
      await ref
          .read(orderServiceProvider)
          .updateOrderStatus(widget.orderId, status, reason: reason);
      await _loadRoom();
      if (!mounted) return;
      _showToast('Order status updated', 'Status is now $status');
      if (status == 'WITHDRAWN') {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showToast('Could not update status', e.toString());
    }
  }

  Future<void> _withdrawOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => FDialog(
        title: const Text('Withdraw Order?'),
        body: const Text(
          'Are you sure you want to withdraw this order? This action cannot be undone, and all participants will be notified.',
        ),
        actions: [
          FButton(
            onPress: () => Navigator.pop(context, false),
            variant: FButtonVariant.outline,
            child: const Text('Cancel'),
          ),
          FButton(
            onPress: () => Navigator.pop(context, true),
            variant: FButtonVariant.destructive,
            child: const Text('Yes, Withdraw'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateOrderStatus('WITHDRAWN');
    }
  }

  Future<void> _reviewItem(OrderItemModel item, {required bool approve}) async {
    final reason = approve ? '' : await _promptForReason();
    if (!approve && (reason == null || reason.trim().isEmpty)) {
      return;
    }

    setState(() => _activeReviewItemId = item.id);
    try {
      if (approve) {
        await ref.read(orderServiceProvider).approveItem(item.id);
      } else {
        await ref
            .read(orderServiceProvider)
            .rejectItem(item.id, reason: reason!);
      }
      await _loadRoom();
      if (!mounted) return;
      _showToast(
        approve ? 'Item approved' : 'Item rejected',
        approve
            ? 'The participant can now move toward payment.'
            : 'The item was rejected and any excess paid amount can be refunded.',
      );
    } catch (e) {
      if (!mounted) return;
      _showToast(
        approve ? 'Could not approve item' : 'Could not reject item',
        e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _activeReviewItemId = null);
      }
    }
  }

  Future<void> _startPayment() async {
    final order = _order;
    final user = _currentUser;
    if (order == null || user == null) return;

    _logPayment('start_payment_clicked', {
      'user_id': user.id,
      'order_status': order.status,
      'title': order.title,
    });

    setState(() => _isPaying = true);
    try {
      _logPayment('create_payment_request_sent');
      final payment = await ref
          .read(orderServiceProvider)
          .createPayment(widget.orderId);
      _logPayment('create_payment_response_received', {
        'transaction_id': payment.transactionId,
        'amount': payment.amount,
        'currency': payment.currency,
        'order_id': payment.gatewayOrderId,
        'key_present': payment.keyId.isNotEmpty,
      });

      if (payment.transactionId <= 0 ||
          payment.gatewayOrderId.isEmpty ||
          payment.keyId.isEmpty ||
          payment.amount <= 0) {
        _logPayment('invalid_payment_payload', {
          'transaction_id': payment.transactionId,
          'amount': payment.amount,
          'order_id': payment.gatewayOrderId,
          'key_len': payment.keyId.length,
        });
        if (!mounted) return;
        setState(() => _isPaying = false);
        _showToast(
          'Invalid payment payload',
          'Checkout payload is incomplete. Please try again.',
        );
        return;
      }

      _pendingPaymentTransactionId = payment.transactionId;
      _paymentFlowTimeout?.cancel();
      _paymentFlowTimeout = Timer(const Duration(seconds: 25), () {
        if (!mounted || !_isPaying) return;
        _logPayment('checkout_timeout', {'transaction_id': _pendingPaymentTransactionId});
        setState(() {
          _isPaying = false;
          _pendingPaymentTransactionId = null;
        });
        _showToast(
          'Checkout did not open',
          'Razorpay did not respond in time. Please try again.',
        );
      });

      final options = {
        'key': payment.keyId,
        'amount': payment.amount,
        'name': 'CartBuddy',
        'order_id': payment.gatewayOrderId,
        'description': 'Order payment for ${order.title}',
        'prefill': {'contact': user.phone, 'email': user.email},
      };
      _logPayment('checkout_open_attempt', {
        'transaction_id': payment.transactionId,
        'gateway_order_id': payment.gatewayOrderId,
        'amount': payment.amount,
      });
      _razorpay.open(options);
      _logPayment('checkout_open_called');
    } catch (e) {
      _logPayment('start_payment_exception', e);
      if (!mounted) return;
      setState(() => _isPaying = false);
      _showToast('Could not start payment', e.toString());
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    _logPayment('sdk_payment_success_callback', {
      'payment_id': response.paymentId,
      'signature_present': (response.signature ?? '').isNotEmpty,
      'order_id': response.orderId,
    });
    _paymentFlowTimeout?.cancel();
    final transactionId = _pendingPaymentTransactionId;
    if (transactionId == null) {
      _logPayment('missing_pending_transaction_in_success_callback');
      return;
    }

    final paymentId = response.paymentId ?? '';
    final signature = response.signature ?? '';
    if (paymentId.isEmpty || signature.isEmpty) {
      _logPayment('success_callback_missing_fields', {
        'payment_id_empty': paymentId.isEmpty,
        'signature_empty': signature.isEmpty,
      });
    }

    try {
      _logPayment('verify_payment_request_sent', {
        'transaction_id': transactionId,
        'payment_id': paymentId,
      });
      await ref
          .read(orderServiceProvider)
          .verifyPayment(
            paymentTransactionId: transactionId,
            razorpayPaymentId: paymentId,
            razorpaySignature: signature,
          );
      _logPayment('verify_payment_success', {'transaction_id': transactionId});
      await _loadRoom();
      if (!mounted) return;
      _showToast('Payment successful', 'Your payment has been verified.');
    } catch (e) {
      _logPayment('verify_payment_exception', e);
      if (!mounted) return;
      _showToast('Could not verify payment', e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isPaying = false;
          _pendingPaymentTransactionId = null;
        });
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _logPayment('sdk_payment_error_callback', {
      'code': response.code,
      'message': response.message,
      'error': response.error,
    });
    if (!mounted) return;
    _paymentFlowTimeout?.cancel();
    setState(() {
      _isPaying = false;
      _pendingPaymentTransactionId = null;
    });
    _showToast(
      'Payment failed',
      response.message ?? 'Razorpay could not complete the payment.',
    );
  }

  void _handleExternalWalletSelected(ExternalWalletResponse response) {
    _logPayment('sdk_external_wallet_selected', {'wallet': response.walletName});
    if (!mounted) return;
    _paymentFlowTimeout?.cancel();
    _showToast(
      'External wallet selected',
      response.walletName ?? 'Complete the payment in your wallet app.',
    );
  }

  Future<String?> _promptForReason() async {
    final controller = TextEditingController(text: 'Item went out of stock.');
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject item'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Item went out of stock.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  void _showToast(String title, String description) {
    showFToast(
      context: context,
      title: Text(title),
      description: Text(description),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Room')),
        body: const Center(child: Text('Order could not be loaded.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(order.title.isEmpty ? 'Order Room' : order.title),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadRoom,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _OrderHeader(
            order: order,
            myParticipant: _myParticipant,
            isJoining: _isJoining,
            onJoin: _myParticipant == null ? _joinOrder : null,
            onWithdraw: _isManager ? _withdrawOrder : null,
          ),
          Material(
            color: AppColors.background,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              indicatorColor: AppColors.secondary,
              tabs: const [
                Tab(text: 'Chat'),
                Tab(text: 'Cart'),
                Tab(text: 'People'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildChatTab(), _buildCartTab(), _buildPeopleTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    final isArchived = _order?.status == 'COMPLETED' || _order?.status == 'WITHDRAWN';

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadRoom,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMine = message.senderId == _currentUser?.id;
                return _ChatBubble(message: message, isMine: isMine);
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: isArchived ? null : (_) => _sendMessage(),
                    readOnly: isArchived,
                    decoration: InputDecoration(
                      hintText: isArchived
                          ? 'This order is ${_order?.status.toLowerCase()}'
                          : 'Message the order room',
                      filled: true,
                      fillColor: isArchived ? Colors.grey[100] : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FButton(
                  onPress: isArchived ? null : _sendMessage,
                  child: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartTab() {
    final myParticipant = _myParticipant;
    final draftItems =
        _items.where((item) => item.participantUserId == _currentUser?.id && item.status == 'DRAFT').toList();
    final submittedItems =
        _items.where((item) => item.participantUserId == _currentUser?.id && item.status != 'DRAFT').toList();

    return RefreshIndicator(
      onRefresh: _loadRoom,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (myParticipant != null &&
              _order?.status == 'ARRIVED' &&
              myParticipant.role != 'CREATOR' &&
              myParticipant.status != 'HANDED_OVER') ...[
            _SectionCard(
              title: 'Handoff OTP',
              child: Column(
                children: [
                  const Text(
                    'Share this OTP with the host to confirm you received your items.',
                    style: TextStyle(color: AppColors.textSub, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingOtp)
                    const CircularProgressIndicator()
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _myOtp ?? 'No OTP found',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (myParticipant == null)
            const _InlinePanel(
              title: 'Join first',
              body:
                  'You need to join this order before adding items, chatting, or paying.',
            )
          else ...[
            _PaymentCard(
              participant: myParticipant,
              isPaying: _isPaying,
              onPay: myParticipant.amountDue > myParticipant.amountPaid
                  ? _startPayment
                  : null,
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Add Item',
              child: Column(
                children: [
                  TextField(
                    controller: _itemNameController,
                    decoration: const InputDecoration(labelText: 'Item name'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _itemQtyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Qty'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _itemPriceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(labelText: 'Price'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _itemNotesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'No onions, extra sauce, etc.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FButton(
                    onPress: _isAddingItem ? null : _addItem,
                    child: Text(_isAddingItem ? 'Adding...' : 'Add Item'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'My Cart',
              child: draftItems.isEmpty && submittedItems.isEmpty
                  ? const Text('No items yet.')
                  : Column(
                      children: [
                        ...draftItems.map((item) => _CartItemTile(item: item)),
                        if (draftItems.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          FButton(
                            onPress: _isSubmittingCart ? null : _submitCart,
                            child: Text(
                              _isSubmittingCart
                                  ? 'Submitting...'
                                  : 'Submit Cart for Review',
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        ...submittedItems.map(
                          (item) => _CartItemTile(item: item),
                        ),
                      ],
                    ),
            ),
          ],
          if (_isManager) ...[
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Manager Actions',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_order?.status == 'OPEN')
                    FButton(
                      onPress: () => _updateOrderStatus('LOCKED'),
                      child: const Text('Lock Order & Stop Joins'),
                    ),
                  if (_order?.status == 'LOCKED')
                    FButton(
                      onPress: () => _updateOrderStatus('PLACED'),
                      child: const Text('Mark as Placed (Checkout Done)'),
                    ),
                  if (_order?.status == 'PLACED')
                    FButton(
                      onPress: () => _updateOrderStatus('ARRIVED'),
                      child: const Text('Mark as Received (Host Got It)'),
                    ),
                  if (_order?.status == 'OPEN' ||
                      _order?.status == 'LOCKED' ||
                      _order?.status == 'PLACED') ...[
                    const SizedBox(height: 12),
                    FButton(
                      onPress: _withdrawOrder,
                      variant: FButtonVariant.destructive,
                      child: const Text('Withdraw Order'),
                    ),
                  ],
                ],
              ),
            ),
            if (_order?.status == 'ARRIVED') ...[
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Handoff Status (Manager)',
                child: Column(
                  children: _participants
                      .where((p) => p.role != 'CREATOR')
                      .map((p) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(p.userName),
                      subtitle: Text(p.status == 'HANDED_OVER'
                          ? '✅ Received'
                          : '⌛ Waiting for OTP'),
                      trailing: p.status != 'HANDED_OVER'
                          ? SizedBox(
                              width: 80,
                              child: TextField(
                                decoration: const InputDecoration(
                                  hintText: 'OTP',
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                buildCounter: (context,
                                        {required currentLength,
                                        required isFocused,
                                        maxLength}) =>
                                    null,
                                onSubmitted: (val) =>
                                    _verifyParticipantOtp(p.id, val),
                              ),
                            )
                          : null,
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Manager Review Queue',
              child: _managerQueue.isEmpty
                  ? const Text('No submitted items waiting for review.')
                  : Column(
                      children: _managerQueue.map((item) {
                        final busy = _activeReviewItemId == item.id;
                        return _ManagerReviewTile(
                          item: item,
                          busy: busy,
                          onApprove: busy
                              ? null
                              : () => _reviewItem(item, approve: true),
                          onReject: busy
                              ? null
                              : () => _reviewItem(item, approve: false),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeopleTab() {
    return RefreshIndicator(
      onRefresh: _loadRoom,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Participants',
            child: Column(
              children: _participants.map((participant) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.secondary.withValues(
                      alpha: 0.14,
                    ),
                    child: Text(
                      participant.userName.isEmpty
                          ? '?'
                          : participant.userName[0].toUpperCase(),
                    ),
                  ),
                  title: Text(participant.userName),
                  subtitle: Text('${participant.role} • ${participant.status}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Due ₹${participant.amountDue.toStringAsFixed(0)}'),
                      Text(
                        'Paid ₹${participant.amountPaid.toStringAsFixed(0)}',
                        style: const TextStyle(color: AppColors.textSub),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  final Order order;
  final OrderParticipantModel? myParticipant;
  final bool isJoining;
  final VoidCallback? onJoin;
  final VoidCallback? onWithdraw;

  const _OrderHeader({
    required this.order,
    required this.myParticipant,
    required this.isJoining,
    required this.onJoin,
    this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.restaurantName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pickup at ${order.meetingPoint}',
            style: const TextStyle(color: AppColors.textSub),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MetaPill(
                label: 'Cart Total',
                value: '₹${order.totalAmount.toStringAsFixed(0)}',
              ),
              const SizedBox(width: 8),
              _MetaPill(
                label: 'Threshold',
                value: '₹${order.minThresholdAmount.toStringAsFixed(0)}',
              ),
              const Spacer(),
              if (onJoin != null)
                FButton(
                  onPress: isJoining ? null : onJoin,
                  child: Text(isJoining ? 'Joining...' : 'Join Order'),
                )
              else
                _MetaPill(
                  label: 'Status',
                  value: order.totalAmount >= order.minThresholdAmount
                      ? 'Met'
                      : '${((order.totalAmount / (order.minThresholdAmount > 0 ? order.minThresholdAmount : 1)) * 100).toStringAsFixed(0)}%',
                ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (order.totalAmount /
                      (order.minThresholdAmount > 0
                          ? order.minThresholdAmount
                          : 1))
                  .clamp(0.0, 1.0),
              backgroundColor: AppColors.background,
              color: order.totalAmount >= order.minThresholdAmount
                  ? Colors.green
                  : AppColors.secondary,
              minHeight: 8,
            ),
          ),
          if (order.totalAmount >= order.minThresholdAmount && order.status == 'OPEN') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(FIcons.check, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Threshold reached! Ready for checkout.',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (order.status == 'LOCKED') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(FIcons.lock, color: AppColors.secondary, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Order locked. Host is placing the order...',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (order.status == 'PLACED') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(FIcons.shoppingBag, color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Order Placed! Waiting for delivery.',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (order.status == 'ARRIVED') ...[
            const SizedBox(height: 12),
            if (order.preparedAt != null) ...[
              _PickupTimer(preparedAt: order.preparedAt!),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(FIcons.packageCheck, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Order Received by Host! Handoff started.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (order.status == 'COMPLETED') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(FIcons.check, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Order Completed! Everyone received their items.',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (order.canManage && (order.status == 'OPEN' || order.status == 'LOCKED')) ...[
            const SizedBox(height: 16),
            FButton(
              onPress: onWithdraw,
              variant: FButtonVariant.destructive,
              child: const Text('Withdraw Order'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetaPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSub),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InlinePanel extends StatelessWidget {
  final String title;
  final String body;

  const _InlinePanel({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: AppColors.textSub)),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final OrderParticipantModel participant;
  final bool isPaying;
  final VoidCallback? onPay;

  const _PaymentCard({
    required this.participant,
    required this.isPaying,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final pending = participant.amountDue - participant.amountPaid;
    return _SectionCard(
      title: 'Payment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Approved total: ₹${participant.amountDue.toStringAsFixed(0)}'),
          const SizedBox(height: 6),
          Text(
            'Already paid: ₹${participant.amountPaid.toStringAsFixed(0)}',
            style: const TextStyle(color: AppColors.textSub),
          ),
          const SizedBox(height: 10),
          Text(
            pending > 0
                ? 'Pending payment: ₹${pending.toStringAsFixed(0)}'
                : 'No payment due right now.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          FButton(
            onPress: onPay,
            child: Text(
              isPaying ? 'Opening Razorpay...' : 'Pay Approved Total',
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final OrderItemModel item;

  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.name} x${item.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              _StatusChip(status: item.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₹${item.lineTotal.toStringAsFixed(0)}',
            style: const TextStyle(color: AppColors.textSub),
          ),
          if (item.specialInstructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.specialInstructions),
          ],
          if (item.reviewReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Reason: ${item.reviewReason}',
              style: const TextStyle(color: AppColors.textSub),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManagerReviewTile extends StatelessWidget {
  final OrderItemModel item;
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ManagerReviewTile({
    required this.item,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.name} x${item.quantity}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'User ${item.participantUserId} • ₹${item.lineTotal.toStringAsFixed(0)}',
              style: const TextStyle(color: AppColors.textSub),
            ),
            if (item.specialInstructions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.specialInstructions),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FButton(
                    onPress: onReject,
                    variant: FButtonVariant.outline,
                    child: Text(
                      busy ? 'Working...' : 'Reject',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FButton(
                    onPress: onApprove,
                    variant: FButtonVariant.primary,
                    child: Text(
                      busy ? 'Working...' : 'Approve',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final OrderChatMessageModel message;
  final bool isMine;

  const _ChatBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final isSystem = message.messageType == 'SYSTEM';
    final alignment = isSystem
        ? Alignment.center
        : (isMine ? Alignment.centerRight : Alignment.centerLeft);
    final color = isSystem
        ? const Color(0xFFFFF1CF)
        : (isMine ? AppColors.secondary.withValues(alpha: 0.18) : Colors.white);

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: isSystem
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            if (!isSystem)
              Text(
                message.senderUsername,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            if (!isSystem) const SizedBox(height: 4),
            Text(
              message.message,
              textAlign: isSystem ? TextAlign.center : TextAlign.start,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = status.toUpperCase();
    final color = switch (label) {
      'APPROVED' => Colors.green,
      'REJECTED' => Colors.red,
      'SUBMITTED' => Colors.orange,
      _ => AppColors.textSub,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _PickupTimer extends StatefulWidget {
  final DateTime preparedAt;

  const _PickupTimer({required this.preparedAt});

  @override
  State<_PickupTimer> createState() => _PickupTimerState();
}

class _PickupTimerState extends State<_PickupTimer> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateRemaining());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _calculateRemaining() {
    final now = DateTime.now();
    final deadline = widget.preparedAt.add(const Duration(minutes: 15));
    setState(() {
      _remaining = deadline.difference(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLate = _remaining.isNegative;
    final absRemaining = _remaining.abs();
    final minutes = absRemaining.inMinutes;
    final seconds = absRemaining.inSeconds % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isLate
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLate ? Colors.red.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLate ? FIcons.circleAlert : FIcons.clock,
            color: isLate ? Colors.red : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLate ? 'PICKUP OVERDUE' : 'PICKUP TIMEOUT',
                  style: TextStyle(
                    color: isLate ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  isLate
                      ? 'Penalty zone: $timeStr late'
                      : 'Time left: $timeStr',
                  style: TextStyle(
                    color: isLate ? Colors.red : AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
