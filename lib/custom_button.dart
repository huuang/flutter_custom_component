library custom_button;

import 'package:flutter/material.dart';

class CustomButton extends StatefulWidget {
  const CustomButton(this.child, this.onTap, {Key key, this.highlightedChild, this.highlightedOpacity}) : super(key: key);

  final Widget child;
  final Widget highlightedChild;
  final double highlightedOpacity;
  final Function onTap;

  _CustomButtonState createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _highlighted = false;
  GlobalKey _key = GlobalKey();

  void _switchHighlight(bool isOn) {
    if (_highlighted != isOn) {
      setState(() {
        _highlighted = isOn;
      });
    }
  }

  Widget build(BuildContext context) {
    return GestureDetector(
      key: _key,
      child: _highlighted
          ? (widget.highlightedChild == null
              ? Opacity(
                  child: widget.child,
                  opacity: _highlighted ? (widget.highlightedOpacity == null ? 0.5 : widget.highlightedOpacity) : 1,
                )
              : widget.highlightedChild)
          : widget.child,
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onPanDown: (details) {
        _switchHighlight(true);
      },
      onTapUp: (details) {
        _switchHighlight(false);
      },
      onTapCancel: () {
        _switchHighlight(false);
      },
      onPanCancel: () {
        _switchHighlight(false);
      },
      onPanEnd: (dragEndDetails) {
        _switchHighlight(false);
      },
    );
  }
}
