import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class PermissionWidget extends StatelessWidget {
  final String requiredRole;
  final Widget child;
  const PermissionWidget({required this.requiredRole, required this.child});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<UserProvider>().role;
    return role == requiredRole ? child : SizedBox.shrink();
  }
}
