import 'package:flutter/material.dart';

class Button extends StatelessWidget {
  const Button({Key? key, required this.callback}) : super(key: key);
  final VoidCallback callback;

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
            color: Colors.amber, borderRadius: BorderRadius.circular(15)),
        child: TextButton(
          onPressed: () {
            callback();
          },
          child: Text("Generate Request",
              style: Theme.of(context).textTheme.bodyText1),
        ));
  }
}
