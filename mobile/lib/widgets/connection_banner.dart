import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart' as svc;

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final socketService = context.watch<svc.SocketService>();
    final state = socketService.connectionState;

    if (state == svc.ConnectionState.connected) {
      return const SizedBox.shrink();
    }

    final isConnecting = state == svc.ConnectionState.connecting;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isConnecting ? const Color(0xFF3A3520) : const Color(0xFF3A2020),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isConnecting)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Color(0xFFC9A96E),
              ),
            )
          else
            const Icon(Icons.cloud_off, size: 14, color: Color(0xFFCC6666)),
          const SizedBox(width: 8),
          Text(
            isConnecting ? 'Bağlanıyor...' : 'Bağlantı kesildi',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: isConnecting ? const Color(0xFFC9A96E) : const Color(0xFFCC6666),
            ),
          ),
        ],
      ),
    );
  }
}
