import 'package:flutter/material.dart';

class Button extends StatelessWidget {
  const Button({Key? key, required this.onTap, required this.text})
      : super(key: key);
  final Function onTap;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
            color: Colors.amber, borderRadius: BorderRadius.circular(15)),
        child: TextButton(
          onPressed: () {
            onTap();
          },
          child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
        ));
  }
}
