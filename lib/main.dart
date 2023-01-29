import 'package:flutter/material.dart';

import './MainPage.dart';

void main() => runApp(new ExampleApplication());

class ExampleApplication extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: MainPage(),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
        )
    );
  }
}
