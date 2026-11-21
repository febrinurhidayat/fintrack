import 'package:flutter/material.dart';

import 'statement_section.dart';

class StatementPage extends StatelessWidget {
  const StatementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-Statement'),
        centerTitle: false,
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: StatementSection(),
        ),
      ),
    );
  }
}
