import 'package:flutter/material.dart';

import 'package:flutter_application_3/ui/app_theme.dart';
import 'package:flutter_application_3/ui/app_widgets.dart';
import 'package:flutter_application_3/screens/products_screen.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              AppPageHeader(
                icon: Icons.inventory_2_outlined,
                title: 'Inventario',
                subtitle: 'Control de stock y movimientos',
                trailing: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gestión de inventario',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Para editar stock, precios, descripciones, imágenes y categorías, usa el módulo Productos.',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GradientButton(
                      text: 'Ir a Productos',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProductsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    SecondaryButton(
                      text: 'Volver al Dashboard',
                      icon: Icons.dashboard_outlined,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
