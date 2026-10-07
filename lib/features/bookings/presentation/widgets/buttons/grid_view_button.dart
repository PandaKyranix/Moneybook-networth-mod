import 'package:flutter/material.dart';

import '../../../../../core/utils/app_localizations.dart';

class GridViewButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  // Kennzeichnet zurückgelegte Konten (nicht im Vermögen) mit einem Schloss-Symbol.
  final bool showLock;

  const GridViewButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.showLock = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(6.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2.0),
        ),
      ),
      child: showLock
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 13.0, color: Colors.amberAccent),
                Flexible(
                  child: Text(
                    AppLocalizations.of(context).translate(text),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.0),
                  ),
                ),
              ],
            )
          : Text(
              AppLocalizations.of(context).translate(text),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.0),
            ),
    );
  }
}
