import 'package:flutter/material.dart';
import 'package:chilli/screens/wallet_screen.dart';
import 'package:chilli/widgets/genz_dialog.dart';

class FundsSheet extends StatelessWidget {
  final num currentBalance;
  final int missedCallsCount;

  const FundsSheet({
    super.key,
    required this.currentBalance,
    this.missedCallsCount = 1,
  });

  @override
  Widget build(BuildContext context) {
    return GenZDialog(
      title: 'LOW BALANCE',
      message: 'Your balance is below ₹5. Add funds to receive and make calls.',
      type: GenZDialogType.warning,
      primaryButtonText: 'ADD FUNDS',
      secondaryButtonText: 'LATER',
      onPrimaryPressed: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WalletScreen(),
          ),
        );
      },
      onSecondaryPressed: () => Navigator.pop(context),
      customContent: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFF9800).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Current Balance',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${currentBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFF9800),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          if (missedCallsCount > 1) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.call_missed_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'You missed $missedCallsCount calls!',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


