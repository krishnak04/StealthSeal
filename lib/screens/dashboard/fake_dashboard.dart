import 'package:flutter/material.dart';

class FakeDashboard extends StatelessWidget {
  const FakeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.shield, color: Colors.cyan),
            SizedBox(width: 8),
            Text('StealthSeal'),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _fakeStatusCard(),
            const SizedBox(height: 20),
            _fakeActions(),
          ],
        ),
      ),
    );
  }

  Widget _fakeStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          _FakeItem(value: '0', label: 'Apps Locked'),
          _FakeItem(value: '0', label: 'Intruders'),
        ],
      ),
    );
  }

  Widget _fakeActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Quick Actions',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          ListTile(
            leading: Icon(Icons.apps),
            title: Text('Manage App Locks'),
            trailing: Icon(Icons.chevron_right),
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            trailing: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _FakeItem extends StatelessWidget {
  final String value;
  final String label;

  const _FakeItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style:
                const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
