import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/company_repository.dart';

/// "Company details & documents" (mockup, Settings → Company & billing) —
/// a read-only view of the company's own submitted verification details.
/// Real data: CompanyRepository.getStatus() already returns every one of
/// these fields (CompanyResource on the backend), the mobile model just
/// hadn't read them until now — no new endpoint needed. Deliberately
/// read-only: editing any of this is a resubmission (CompanyVerification
/// Screen), a different, heavier flow than a settings row should trigger.
class CompanyDetailsScreen extends StatefulWidget {
  CompanyDetailsScreen({super.key, CompanyRepository? repository}) : repository = repository ?? CompanyRepository();

  final CompanyRepository repository;

  @override
  State<CompanyDetailsScreen> createState() => _CompanyDetailsScreenState();
}

class _CompanyDetailsScreenState extends State<CompanyDetailsScreen> {
  late Future<CompanyVerification?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.getStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Company details')),
      body: FutureBuilder<CompanyVerification?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final company = snapshot.data;
          if (snapshot.hasError || company == null) {
            return const Center(child: Text('Could not load your company details.'));
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _DetailRow(label: 'Company name', value: company.companyName),
              _DetailRow(label: 'Registration number', value: company.registrationNumber),
              _DetailRow(label: 'TIN', value: company.tin),
              _DetailRow(label: 'Physical address', value: company.physicalAddress),
              _DetailRow(label: 'Company phone', value: company.companyPhone),
              _DetailRow(label: 'Company email', value: company.companyEmail),
              const SizedBox(height: 12),
              const Text(
                'Representative',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textLabel),
              ),
              const SizedBox(height: 8),
              _DetailRow(label: 'Name', value: company.repFullName),
              _DetailRow(label: 'Position', value: company.repPosition),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value ?? '—', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
