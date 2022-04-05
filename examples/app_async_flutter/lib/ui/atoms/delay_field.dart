import 'package:flutter/material.dart';

class DelayField extends StatelessWidget {
  const DelayField({
    Key? key,
    required this.textEditingController,
  }) : super(key: key);

  final TextEditingController textEditingController;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: textEditingController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        border: UnderlineInputBorder(),
        icon: Icon(Icons.lock_clock_outlined),
        labelText: "Delay service in ms",
      ),
    );
  }
}
