import 'package:flutter/material.dart';

class InputField extends StatelessWidget {
  const InputField(
      {Key? key,
      required this.textEditingController,
      this.keyboardType = TextInputType.number,
      required this.labelText,
      this.icon})
      : super(key: key);

  final TextEditingController textEditingController;
  final TextInputType? keyboardType;
  final String labelText;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: textEditingController,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        border: const UnderlineInputBorder(),
        icon: Icon(icon),
        labelText: labelText,
      ),
    );
  }
}
