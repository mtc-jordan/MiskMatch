import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/game_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// Renders the correct input UI for every question type:
///
///   open_text      — multiline text field (Qalb Quiz, Honesty Box, etc.)
///   multiple_choice— tappable option cards (Would You Rather, Islamic Trivia)
///   ranking        — drag-to-reorder list (Priority Ranking, Values Map)
///   completion     — fill-in-the-blank (Finish My Sentence)
///   letter_prompt  — prompted letter/story entry (Build Our Story)
///   slider         — 1-10 scale (Love Languages dimension)
///   boolean        — yes / no (Deal or No Deal)

class QuestionView extends StatefulWidget {
  const QuestionView({
    super.key,
    required this.question,
    required this.gameType,
    required this.gameState,
    required this.isSubmitting,
    required this.onSubmitAsync,
    required this.onSubmitRealtime,
  });

  final Map<String, dynamic> question;
  final String               gameType;
  final GameState            gameState;
  final bool                 isSubmitting;
  final Future<dynamic> Function(String answer,
      {Map<String, dynamic>? answerData}) onSubmitAsync;
  final Future<dynamic> Function(String questionId, String answer)
      onSubmitRealtime;

  @override
  State<QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<QuestionView> {
  final _textCtrl   = TextEditingController();
  String? _selected;           // MCQ / boolean selected option
  List<String> _ranking = [];  // current order for ranking
  double  _sliderValue  = 5;
  bool    _submitted    = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate ranking from question options
    final opts = widget.question['options'] as List<dynamic>?;
    if (opts != null) {
      _ranking = opts.map((o) => o.toString()).toList();
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  String get _questionId =>
      widget.question['id']?.toString() ?? '';

  String get _questionType =>
      widget.question['type']?.toString() ?? 'open_text';

  String get _questionText =>
      widget.question['text']?.toString() ??
      widget.question['stem']?.toString() ??
      widget.question['q']?.toString() ?? '';

  String get _contextHint =>
      widget.question['context']?.toString() ?? '';

  List<String> get _options {
    final raw = widget.question['options'] as List<dynamic>?;
    return raw?.map((o) => o.toString()).toList() ?? [];
  }

  bool get _isRealTime =>
      widget.gameType == 'would_you_rather' ||
      widget.gameType == 'islamic_trivia'   ||
      widget.gameType == 'geography_race';

  // ── SUBMIT ─────────────────────────────────────────────────────────────────
  Future<void> _submit(String answer) async {
    if (_submitted || widget.isSubmitting) return;
    setState(() => _submitted = true);

    if (_isRealTime) {
      await widget.onSubmitRealtime(_questionId, answer);
    } else {
      final answerData = _questionType == 'ranking'
          ? {'order': _ranking}
          : _questionType == 'slider'
              ? {'value': _sliderValue.round()}
              : null;
      await widget.onSubmitAsync(answer, answerData: answerData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPadding, 20,
          AppSpacing.screenPadding, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Turn / progress indicator
          _TurnIndicator(state: widget.gameState),
          const SizedBox(height: 20),

          // Question card
          _QuestionCard(
            text:    _questionText,
            context: _contextHint,
            type:    _questionType,
          ),
          const SizedBox(height: 24),

          // Input area — switches on question type
          _buildInput(context),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    switch (_questionType) {
      case 'multiple_choice':
        return _MCQInput(
          options:      _options,
          selected:     _selected,
          isSubmitting: widget.isSubmitting || _submitted,
          onSelect: (opt) {
            setState(() => _selected = opt);
            _submit(opt);
          },
        );

      case 'boolean':
        return _BooleanInput(
          isSubmitting: widget.isSubmitting || _submitted,
          selected:     _selected,
          onSelect: (v) {
            setState(() => _selected = v);
            _submit(v);
          },
        );

      case 'ranking':
        return _RankingInput(
          items:        _ranking,
          isSubmitting: widget.isSubmitting || _submitted,
          onReorder:    (items) => setState(() => _ranking = items),
          onSubmit:     () => _submit(_ranking.join('|')),
        );

      case 'slider':
        return _SliderInput(
          value:        _sliderValue,
          label:        widget.question['scale_label']?.toString() ?? '',
          isSubmitting: widget.isSubmitting || _submitted,
          onChanged:    (v) => setState(() => _sliderValue = v),
          onSubmit:     () => _submit(_sliderValue.round().toString()),
        );

      case 'completion':
        return _CompletionInput(
          stem:         _questionText,
          controller:   _textCtrl,
          isSubmitting: widget.isSubmitting || _submitted,
          onSubmit:     () => _submit(_textCtrl.text.trim()),
        );

      case 'letter_prompt':
      case 'open_text':
      default:
        return _OpenTextInput(
          hint:         widget.question['placeholder']?.toString() ??
                        'Write your answer...',
          controller:   _textCtrl,
          maxLines:     _questionType == 'letter_prompt' ? 8 : 5,
          isSubmitting: widget.isSubmitting || _submitted,
          onSubmit:     () => _submit(_textCtrl.text.trim()),
          minLength:    _questionType == 'letter_prompt' ? 30 : 5,
        );
    }
  }
}

// ─────────────────────────────────────────────
// TURN INDICATOR
// ─────────────────────────────────────────────

class _TurnIndicator extends StatelessWidget {
  const _TurnIndicator({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        AppColors.roseDeep.withOpacity(0.08),
          borderRadius: AppRadius.chipRadius,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.edit_note_rounded,
              color: AppColors.roseDeep, size: 16),
          const SizedBox(width: 6),
          Text('Turn ${state.turnNumber + 1} of ${state.totalTurns}',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.roseDeep)),
        ]),
      ),
      const Spacer(),
      // Progress dots
      ...List.generate(state.totalTurns.clamp(0, 12), (i) {
        final done = i < state.turnNumber;
        final curr = i == state.turnNumber;
        return Container(
          width:  curr ? 10 : 6,
          height: curr ? 10 : 6,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: done
                ? AppColors.roseDeep
                : curr
                    ? AppColors.roseBlush
                    : AppColors.neutral300,
            shape: BoxShape.circle,
          ),
        );
      }),
    ]);
  }
}

// ─────────────────────────────────────────────
// QUESTION CARD
// ─────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.text,
    required this.context,
    required this.type,
  });
  final String text;
  final String context;
  final String type;

  @override
  Widget build(BuildContext context_) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [
            AppColors.roseDeep.withOpacity(0.06),
            AppColors.goldPrimary.withOpacity(0.03),
          ],
        ),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.roseDeep.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (context.isNotEmpty) ...[
            Text(context,
                style: AppTypography.bodySmall.copyWith(
                  color:     AppColors.neutral500,
                  fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
          ],
          Text(
            text,
            style: AppTypography.titleMedium.copyWith(
              color:  AppColors.neutral900,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.04, end: 0);
  }
}

// ─────────────────────────────────────────────
// MULTIPLE CHOICE
// ─────────────────────────────────────────────

class _MCQInput extends StatelessWidget {
  const _MCQInput({
    required this.options,
    required this.selected,
    required this.isSubmitting,
    required this.onSelect,
  });
  final List<String>         options;
  final String?              selected;
  final bool                 isSubmitting;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: options.indexed.map((e) {
        final i   = e.$1;
        final opt = e.$2;
        final isSelected = selected == opt;

        return GestureDetector(
          onTap: isSubmitting ? null : () => onSelect(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin:   const EdgeInsets.only(bottom: 10),
            padding:  const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isSelected ? AppColors.roseGradient : null,
              color:    isSelected ? null : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : theme.colorScheme.outline.withOpacity(0.4),
                width: isSelected ? 0 : 1,
              ),
              boxShadow: isSelected ? AppShadows.card : [],
            ),
            child: Row(children: [
              Expanded(
                child: Text(opt,
                    style: AppTypography.bodyMedium.copyWith(
                      color:      isSelected ? AppColors.white : AppColors.neutral900,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    )),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.white, size: 20),
            ]),
          ),
        )
            .animate(delay: Duration(milliseconds: i * 60))
            .fadeIn(duration: 300.ms)
            .slideX(begin: -0.04, end: 0);
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────
// BOOLEAN  (Yes / No)
// ─────────────────────────────────────────────

class _BooleanInput extends StatelessWidget {
  const _BooleanInput({
    required this.isSubmitting,
    required this.selected,
    required this.onSelect,
  });
  final bool                 isSubmitting;
  final String?              selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: _BoolBtn(
          label:      'Yes',
          icon:       Icons.check_circle_outline_rounded,
          color:      AppColors.success,
          selected:   selected == 'yes',
          onTap:      isSubmitting ? null : () => onSelect('yes'),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _BoolBtn(
          label:      'No',
          icon:       Icons.cancel_outlined,
          color:      AppColors.error,
          selected:   selected == 'no',
          onTap:      isSubmitting ? null : () => onSelect('no'),
        ),
      ),
    ]);
  }
}

class _BoolBtn extends StatelessWidget {
  const _BoolBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String       label;
  final IconData     icon;
  final Color        color;
  final bool         selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 72,
        decoration: BoxDecoration(
          color:        selected ? color : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? Colors.transparent : color.withOpacity(0.3),
          ),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              color: selected ? AppColors.white : color,
              size:  28),
          const SizedBox(height: 4),
          Text(label,
              style: AppTypography.labelLarge.copyWith(
                color: selected ? AppColors.white : color)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// RANKING  (drag to reorder)
// ─────────────────────────────────────────────

class _RankingInput extends StatelessWidget {
  const _RankingInput({
    required this.items,
    required this.isSubmitting,
    required this.onReorder,
    required this.onSubmit,
  });
  final List<String>              items;
  final bool                      isSubmitting;
  final void Function(List<String>) onReorder;
  final VoidCallback              onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(children: [
      Text('Drag to rank from most to least important:',
          style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500)),
      const SizedBox(height: 12),
      ReorderableListView(
        shrinkWrap: true,
        physics:    const NeverScrollableScrollPhysics(),
        onReorder: (oldIndex, newIndex) {
          final updated = List<String>.from(items);
          if (newIndex > oldIndex) newIndex--;
          final item = updated.removeAt(oldIndex);
          updated.insert(newIndex, item);
          onReorder(updated);
        },
        children: items.indexed.map((e) {
          final i    = e.$1;
          final item = e.$2;
          return Container(
            key:    ValueKey(item),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color:        theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.3)),
            ),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                radius:          14,
                backgroundColor: AppColors.roseDeep.withOpacity(0.1),
                child: Text('${i + 1}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.roseDeep, fontWeight: FontWeight.w700)),
              ),
              title: Text(item, style: AppTypography.bodyMedium),
              trailing: const Icon(Icons.drag_handle_rounded,
                  color: AppColors.neutral500, size: 20),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
      MiskButton(
        label:     'Submit ranking',
        onPressed: isSubmitting ? null : onSubmit,
        loading:   isSubmitting,
        icon:      Icons.check_rounded,
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// SLIDER  (1-10 scale)
// ─────────────────────────────────────────────

class _SliderInput extends StatelessWidget {
  const _SliderInput({
    required this.value,
    required this.label,
    required this.isSubmitting,
    required this.onChanged,
    required this.onSubmit,
  });
  final double               value;
  final String               label;
  final bool                 isSubmitting;
  final void Function(double) onChanged;
  final VoidCallback         onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(
          '${value.round()}',
          style: AppTypography.headlineLarge.copyWith(
            color: AppColors.roseDeep, fontWeight: FontWeight.w700),
        ),
        Text(' / 10',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.neutral500)),
      ]),
      const SizedBox(height: 4),
      if (label.isNotEmpty)
        Text(label, style: AppTypography.bodySmall.copyWith(
          color: AppColors.neutral500, fontStyle: FontStyle.italic)),
      const SizedBox(height: 16),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor:   AppColors.roseDeep,
          inactiveTrackColor: AppColors.roseLight.withOpacity(0.3),
          thumbColor:         AppColors.roseDeep,
          overlayColor:       AppColors.roseDeep.withOpacity(0.15),
          trackHeight:        6,
          thumbShape:         const RoundSliderThumbShape(enabledThumbRadius: 14),
        ),
        child: Slider(
          value: value, min: 1, max: 10,
          divisions: 9,
          onChanged: isSubmitting ? null : onChanged,
        ),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('1 — Not at all',
            style: AppTypography.labelSmall.copyWith(color: AppColors.neutral500)),
        Text('10 — Absolutely',
            style: AppTypography.labelSmall.copyWith(color: AppColors.neutral500)),
      ]),
      const SizedBox(height: 24),
      MiskButton(
        label:     'Submit',
        onPressed: isSubmitting ? null : onSubmit,
        loading:   isSubmitting,
        icon:      Icons.check_rounded,
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// COMPLETION  (fill-in-the-blank)
// ─────────────────────────────────────────────

class _CompletionInput extends StatelessWidget {
  const _CompletionInput({
    required this.stem,
    required this.controller,
    required this.isSubmitting,
    required this.onSubmit,
  });
  final String                 stem;
  final TextEditingController  controller;
  final bool                   isSubmitting;
  final VoidCallback           onSubmit;

  // Split the stem on "___" to show parts before/after blank
  List<String> get _parts => stem.split('___');

  @override
  Widget build(BuildContext context) {
    final hasBlank = _parts.length > 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (hasBlank) ...[
        // Show sentence with inline field
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(_parts[0],
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.neutral900, height: 1.6)),
          Container(
            width: 120,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                isDense:       true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              style: AppTypography.bodyLarge.copyWith(
                color:      AppColors.roseDeep,
                fontWeight: FontWeight.w600),
            ),
          ),
          if (_parts.length > 1)
            Text(_parts[1],
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.neutral900, height: 1.6)),
        ]),
        const SizedBox(height: 20),
      ] else ...[
        MiskTextField(
          label:      'Complete the sentence',
          controller: controller,
          maxLines:   3,
          onChanged:  (_) {},
        ),
        const SizedBox(height: 16),
      ],
      MiskButton(
        label:     'Submit',
        onPressed: isSubmitting || controller.text.trim().length < 2
            ? null
            : onSubmit,
        loading:   isSubmitting,
        icon:      Icons.check_rounded,
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// OPEN TEXT
// ─────────────────────────────────────────────

class _OpenTextInput extends StatefulWidget {
  const _OpenTextInput({
    required this.hint,
    required this.controller,
    required this.maxLines,
    required this.isSubmitting,
    required this.onSubmit,
    this.minLength = 5,
  });
  final String                hint;
  final TextEditingController controller;
  final int                   maxLines;
  final bool                  isSubmitting;
  final VoidCallback          onSubmit;
  final int                   minLength;

  @override
  State<_OpenTextInput> createState() => _OpenTextInputState();
}

class _OpenTextInputState extends State<_OpenTextInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  bool get _canSubmit =>
      widget.controller.text.trim().length >= widget.minLength &&
      !widget.isSubmitting;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextFormField(
        controller: widget.controller,
        maxLines:   widget.maxLines,
        minLines:   3,
        maxLength:  500,
        decoration: InputDecoration(
          hintText:       widget.hint,
          hintStyle:      AppTypography.bodyMedium.copyWith(
            color: AppColors.neutral500),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.roseDeep, width: 2)),
        ),
        style: AppTypography.bodyMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurface, height: 1.55),
      ),
      const SizedBox(height: 6),
      // Min length hint
      AnimatedOpacity(
        opacity: widget.controller.text.trim().length < widget.minLength ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Text(
          '${widget.minLength - widget.controller.text.trim().length} more '
          'character${widget.controller.text.trim().length + 1 == widget.minLength ? '' : 's'} needed',
          style: AppTypography.labelSmall.copyWith(color: AppColors.neutral500),
        ),
      ),
      const SizedBox(height: 16),
      MiskButton(
        label:     'Submit answer',
        onPressed: _canSubmit ? widget.onSubmit : null,
        loading:   widget.isSubmitting,
        icon:      Icons.send_rounded,
      ),
    ]);
  }
}
