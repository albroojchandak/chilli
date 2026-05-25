import 'package:flutter/material.dart';

class RefundPolicy {
  static String getRefundPolicyTitle() {
    return "Refund Policy";
  }

  static String getRefundPolicyText() {
    return '''
# Refund Policy

## 1. Overview
At chilli, we strive to ensure your satisfaction with our services. This refund policy outlines the terms and conditions regarding refunds for purchases made through our application.

## 2. Eligibility for Refunds
### 2.1 Eligible Refund Scenarios:
- Service unavailability due to technical issues on our end
- Incorrect charges or billing errors
- Premium features not delivered as described

### 2.2 Ineligible Refund Scenarios:
- Requests made after 14 days of purchase
- Services that have been fully or partially consumed
- Cancellation of subscription after the billing cycle has begun
- Purchases made using promotional credits or GiftModel cards

## 3. Refund Process
### 3.1 How to Request a Refund:
- Contact our customer support team through the app's "Help & Support" section
- Provide your transaction ID and reason for refund
- Submit any relevant documentation or evidence if applicable

### 3.2 Processing Time:
- Refund requests are typically processed within 3-5 business days
- The actual refund may take 7-14 business days to reflect in your account, depending on your payment provider

## 4. Special Considerations
### 4.1 Subscription Cancellations:
- Cancelling a subscription will not result in a refund for the current billing period
- Subscription will remain active until the end of the current billing cycle

### 4.2 Technical Issues:
- If you experience technical issues that prevent you from using our service, please contact our support team before requesting a refund so we can attempt to resolve the issue

## 5. Changes to This Policy
We reserve the right to modify this refund policy at any time. Changes will be effective immediately upon posting to the app.

Last Updated: ${DateTime.now().toString().split(' ')[0]}
''';
  }

  static Widget getRefundPolicyWidget(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(getRefundPolicyTitle()),
        centerTitle: true,
        elevation: 0,
      ),
      body: const RefundPolicyContent(),
    );
  }
}

class RefundPolicyContent extends StatelessWidget {
  const RefundPolicyContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(context),
              const SizedBox(height: 16),
              _buildSectionCard(
                context,
                title: "Eligibility for Refunds",
                icon: Icons.check_circle_outline,
                content: _buildEligibilityContent(context),
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                context,
                title: "Refund Process",
                icon: Icons.sync,
                content: _buildProcessContent(context),
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                context,
                title: "Special Considerations",
                icon: Icons.info_outline,
                content: _buildConsiderationsContent(context),
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                context,
                title: "Changes to This Policy",
                icon: Icons.update,
                content: _buildChangesContent(context),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  "Last Updated: ${DateTime.now().toString().split(' ')[0]}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  "This app is owned and operated by INFLYRATECH PRIVATE LIMITED.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.7),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              RefundPolicy.getRefundPolicyTitle(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "At chilli, we strive to ensure your satisfaction with our services. This refund policy outlines the terms and conditions regarding refunds for purchases made through our application.",
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildEligibilityContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubsection(
          context,
          title: "Eligible Refund Scenarios:",
          items: [
            "Service unavailability due to technical issues on our end",
            "Incorrect charges or billing errors",
            "Premium features not delivered as described",
          ],
        ),
        const SizedBox(height: 16),
        _buildSubsection(
          context,
          title: "Ineligible Refund Scenarios:",
          items: [
            "Requests made after 2 days of purchase",
            "Services that have been fully or partially consumed",
            "Cancellation of subscription after the billing cycle has begun",
            "Purchases made using promotional credits or GiftModel cards",
          ],
        ),
      ],
    );
  }

  Widget _buildProcessContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubsection(
          context,
          title: "How to Request a Refund:",
          items: [
            "Contact our customer support team through the app's \"Help & Support\" section",
            "Provide your transaction ID and reason for refund",
            "Submit any relevant documentation or evidence if applicable",
          ],
        ),
        const SizedBox(height: 16),
        _buildSubsection(
          context,
          title: "Processing Time:",
          items: [
            "Refund requests are typically processed within 3-5 business days",
            "The actual refund may take 7-14 business days to reflect in your account, depending on your payment provider",
          ],
        ),
      ],
    );
  }

  Widget _buildConsiderationsContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubsection(
          context,
          title: "Subscription Cancellations:",
          items: [
            "Cancelling a subscription will not result in a refund for the current billing period",
            "Subscription will remain active until the end of the current billing cycle",
          ],
        ),
        const SizedBox(height: 16),
        _buildSubsection(
          context,
          title: "Technical Issues:",
          items: [
            "If you experience technical issues that prevent you from using our service, please contact our support team before requesting a refund so we can attempt to resolve the issue",
          ],
        ),
      ],
    );
  }

  Widget _buildChangesContent(BuildContext context) {
    return Text(
      "We reserve the right to modify this refund policy at any time. Changes will be effective immediately upon posting to the app.",
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildSubsection(
    BuildContext context, {
    required String title,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.arrow_right, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
