import 'package:flutter/material.dart';
import 'models.dart';
import 'package:expenses/widgets/custom_modal_dialog.dart';
import 'utils/id_generator.dart';

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
  String? _errorMessage;

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
      setState(() {
        _errorMessage = 'Please enter a category name';
      });
      return;
    }

    final newCat = ExpenseCategory(
      id: IdGenerator.generateCategoryId(),
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

    return CustomModalDialog(
      icon: _selectedIcon,
      iconColor: _selectedColor,
      iconBackgroundColor: _selectedColor.withValues(alpha: 0.2),
      title: 'Add Custom Category',
      subtitle: 'Pick an icon, color, and name for your new category',
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
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) {
                if (_errorMessage != null) setState(() => _errorMessage = null);
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 16, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text('Select Icon', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
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
                        color: isSelected ? _selectedColor.withValues(alpha: 0.2) : theme.colorScheme.surfaceContainerHigh,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? _selectedColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? _selectedColor : theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text('Select Color', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      primaryButtonText: 'Create Category',
      primaryButtonColor: _selectedColor,
      onPrimaryPressed: _submit,
    );
  }
}
