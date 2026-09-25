import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/screen_header.dart';
import '../widgets/primary_button.dart';

class FeedbackScreen extends StatefulWidget {
  final ValueChanged<String> go;

  const FeedbackScreen({super.key, required this.go});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final List<int?> _answers = List.filled(10, null);
  int _step = 0;
  bool _done = false;

  final _questions = const [
    "I think that I would like to use this system frequently.",
    "I found the system unnecessarily complex.",
    "I thought the system was easy to use.",
    "I think that I would need support to use this system.",
    "I found the various functions well integrated.",
    "I thought there was too much inconsistency in the system.",
    "I imagine most people would learn to use this system quickly.",
    "I found the system very cumbersome to use.",
    "I felt very confident using the system.",
    "I needed to learn a lot before I could get going with this system.",
  ];

  final _scale = const [
    "Strongly disagree",
    "Disagree",
    "Neutral",
    "Agree",
    "Strongly agree",
  ];

  @override
  Widget build(BuildContext context) {
    final allAnswered = _answers.every((a) => a != null);

    if (_done) {
      return Column(
        children: [
          ScreenHeader(
            title: 'App feedback',
            onBack: () => widget.go('profile'),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: FarmoraColors.goodSoft,
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(Icons.check, size: 26, color: FarmoraColors.good),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Thanks for the feedback',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: FarmoraColors.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your responses help the Farmora team improve the field experience.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 12.5, color: FarmoraColors.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        ScreenHeader(
          title: 'App feedback — help us grow',
          onBack: () => widget.go('profile'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question ${_step + 1} of 10 · Standard usability scale',
                style: TextStyle(fontSize: 11, color: FarmoraColors.inkSoft),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (_step + 1) / 10,
                  backgroundColor: FarmoraColors.line,
                  color: FarmoraColors.brand,
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _questions[_step],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: FarmoraColors.ink,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              ...List.generate(_scale.length, (idx) {
                final label = _scale[idx];
                final selected = _answers[_step] == idx;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() => _answers[_step] = idx);
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 11),
                      decoration: BoxDecoration(
                        color: selected
                            ? FarmoraColors.brandSoft
                            : FarmoraColors.surface,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: selected
                              ? FarmoraColors.brand
                              : FarmoraColors.line,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? FarmoraColors.brand
                                    : FarmoraColors.inkFaint,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: selected
                                ? Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: FarmoraColors.brand,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              color: FarmoraColors.ink,
                              fontWeight:
                                  selected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: FarmoraColors.line)),
          ),
          child: Row(
            children: [
              if (_step > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _step--),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: FarmoraColors.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: FarmoraColors.ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: _step < 9
                    ? PrimaryButton(
                        text: 'Next question',
                        disabled: _answers[_step] == null,
                        onClick: () => setState(() => _step++),
                      )
                    : PrimaryButton(
                        text: 'Submit feedback',
                        disabled: !allAnswered,
                        onClick: () => setState(() => _done = true),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
