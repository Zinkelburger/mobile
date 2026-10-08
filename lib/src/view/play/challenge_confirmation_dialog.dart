import 'package:lichess_mobile/src/model/challenge/challenge.dart';
import 'package:lichess_mobile/src/styles/icon_extensions.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/widgets/platform_alert_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// Asks the user to confirm before a challenge is sent to another player.
///
/// Returns `true` when there is nothing to confirm: open challenges (no one receives them) and
/// challenges to bots (they answer instantly and the user picked the bot on purpose).
Future<bool> confirmChallenge(BuildContext context, ChallengeRequest request) async {
  final destUser = request.destUser;
  if (destUser == null || destUser.isBot) return true;
  final confirmed = await showAdaptiveDialog<bool>(
    context: context,
    builder: (context) => ChallengeConfirmationDialog(request: request),
  );
  return confirmed ?? false;
}

/// Summarizes who is being challenged and on which terms, so that sending a challenge is a
/// deliberate step.
class const ChallengeConfirmationDialog({super.key, required final ChallengeRequest request})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final timeControl =
        request.timeIncrement?.display ??
        (request.days != null
            ? '${context.l10n.daysPerTurn}: ${request.days}'
            : context.l10n.unlimited);
    final terms = [
      if (request.rated) context.l10n.rated else context.l10n.casual,
      request.variant.label(context.l10n),
      request.sideChoice.label(context.l10n),
    ].join(' • ');

    return AlertDialog.adaptive(
      title: Text(context.l10n.challengeX(request.destUser?.name ?? '')),
      content: Column(
        mainAxisSize: .min,
        children: [
          const SizedBox(height: 12.0),
          Row(
            mainAxisAlignment: .center,
            mainAxisSize: .min,
            children: [
              Icon(request.perf.icon, color: DefaultTextStyle.of(context).style.color),
              const SizedBox(width: 8.0),
              Flexible(child: Text(timeControl, style: TextTheme.of(context).titleLarge)),
            ],
          ),
          const SizedBox(height: 4.0),
          Text(terms, textAlign: .center),
        ],
      ),
      actions: [
        PlatformDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        PlatformDialogAction(
          cupertinoIsDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Send challenge'),
        ),
      ],
    );
  }
}
