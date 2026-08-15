import 'package:flutter/material.dart';
import 'models.dart';

class AddCategoryDialog extends StatefulWidget {
  final Function(ExpenseCategory) onAddCategory;

  const AddCategoryDialog({
    super.key,
    required this.onAddCategory,
  });

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _nameController = TextEditingController();

  static const List<IconData> _availableIcons = [
    Icons.fastfood_rounded,
    Icons.shopping_cart_rounded,
    Icons.directions_bus_rounded,
    Icons.flight_rounded,
    Icons.medical_services_rounded,
    Icons.school_rounded,
    Icons.fitness_center_rounded,
    Icons.pets_rounded,
    Icons.local_cafe_rounded,
    Icons.card_giftcard_rounded,
    Icons.devices_rounded,
    Icons.home_rounded,
    Icons.build_rounded,
    Icons.sports_esports_rounded,
    Icons.savings_rounded,
    Icons.work_rounded,
  ];

  static const List<Color> _availableColors = [
    Color(0xFFFF6B6B),
    Color(0xFFFF9F43),
    Color(0xFFFECA57),
    Color(0xFF1DD1A1),
    Color(0xFF10AC84),
    Color(0xFF48DBFB),
    Color(0xFF54A0FF),
    Color(0xFF5F27CD),
    Color(0xFFFF9FF3),
    Color(0xFF8395A7),
    Color(0xFFEE5253),
    Color(0xFF0ABDE3),
  ];

  late IconData _selectedIcon;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedIcon = _availableIcons.first;
    _selectedColor = _availableColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter category name')),
      );
      return;
    }

    final newCat = ExpenseCategory(
      id: 'cat_custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      icon: _selectedIcon,
      color: _selectedColor,
    );

    widget.onAddCategory(newCat);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Custom Category', style: TextStyle(fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g. Subscriptions, Gaming, Books',
                prefixIcon: const Icon(Icons.label_outline_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Select Icon', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              width: double.maxFinite,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _availableIcons.length,
                itemBuilder: (context, index) {
                  final icon = _availableIcons[index];
                  final isSelected = icon == _selectedIcon;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIcon = icon;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? _selectedColor.withAlpha(50) : theme.colorScheme.surfaceContainerHigh,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? _selectedColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? _selectedColor : theme.colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text('Select Color', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availableColors.map((color) {
                final isSelected = color == _selectedColor;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? theme.colorScheme.onSurface : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Create Category'),
        ),
      ],
    );
  }
}
