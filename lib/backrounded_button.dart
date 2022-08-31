import 'package:flutter/material.dart';

class BackrButton extends StatelessWidget { //A button with a backround
String _path;
Function _func;

BackrButton(this._func, this._path);

@override
Widget build(BuildContext context) {
return Center(
        child: IconButton(
          splashRadius: 30,
          iconSize: 45,
          icon: Container(child: Image(image: AssetImage(_path), width: 800, height: 50,)),
          onPressed: () { _func(); },
        ),
      );

}
}
