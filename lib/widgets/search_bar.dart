import 'package:flutter/cupertino.dart';
import '../theme.dart';

class CustomSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;

  const CustomSearchBar({
    super.key,
    this.controller,
    required this.placeholder,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoSearchTextField(
      controller: controller,
      placeholder: placeholder,
      style: TextStyle(
        color: AppTextColors.primary(context),
        fontSize: 16,
      ),
      placeholderStyle: TextStyle(
        color: AppTextColors.quaternary(context),
        fontSize: 16,
      ),
      backgroundColor: AppSurfaces.elevated(context),
      onChanged: onChanged,
    );
  }
}
