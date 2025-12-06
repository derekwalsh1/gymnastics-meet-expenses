import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text('App Preferences'),
            subtitle: Text('Coming Soon'),
          ),
          const Divider(),
          const ListTile(
            title: Text('Default Mileage Rate'),
            subtitle: Text('\$0.67 per mile'),
          ),
          const ListTile(
            title: Text('Default Per Diem Rates'),
            subtitle: Text('Configure meal rates'),
          ),
          const Divider(),
          ListTile(
            title: const Text('Backup Data'),
            trailing: const Icon(Icons.backup),
            onTap: () {
              // TODO: Implement backup
            },
          ),
          ListTile(
            title: const Text('Restore Data'),
            trailing: const Icon(Icons.restore),
            onTap: () {
              // TODO: Implement restore
            },
          ),
          const Divider(),
          const ListTile(
            title: Text('App Version'),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }
}
