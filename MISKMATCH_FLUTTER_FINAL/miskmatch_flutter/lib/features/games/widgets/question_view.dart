import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/game_models.dart';
import 'package:miskmatch/core/theme/app_colors.dart';
import 'package:miskmatch/core/theme/app_theme.dart';
import 'package:miskmatch/core/theme/app_typography.dart';
import 'package:miskmatch/shared/widgets/common_widgets.dart';

/// Renders the correct input UI for every question type:
///
///   open_text       — multiline text field
///   multiple_choice — tappable option cards
///   ranking         — drag-to-reorder list
///   completion      — fill-in-the-blank
///   letter_prompt   — prompted letter/story entry
///   slider          — 1-10 scale
///   boolean         — yes / no

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
  String? _selected;
  List<String> _ranking = [];
  double  _sliderValue  = 5;
  bool    _submitted    = false;

  @override
  void initState() {
    super.initState();
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Turn indicator
          _TurnIndicator(state: widget.gameState),
          const SizedBox(height: 20),

          // Question card
          _QuestionCard(
            text:        _questionText,
            contextHint: _contextHint,
          ),
          const SizedBox(height: 24),

          // Input area
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
            HapticFeedback.selectionClick();
            setState(() => _selected = opt);
            _submit(opt);
          },
        );

      case 'boolean':
        return _BooleanInput(
          isSubmitting: widget.isSubmitting || _submitted,
          selected:     _selected,
          onSelect: (v) {
            HapticFeedback.selectionClick();
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
// Left: "Turn N of M" chip (roseDeep bg, white)
// Right: progress dots (filled/unfilled, max 12)
// ─────────────────────────────────────────────

class _TurnIndicator extends StatelessWidget {
  const _TurnIndicator({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Turn chip — roseDeep bg, white text
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:        AppColors.roseDeep,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            'Turn ${state.turnNumber + 1} of ${state.totalTurns}',
            style: AppTypography.labelMedium.copyWith(
              color:      AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const Spacer(),

        // Progress dots
        ...List.generate(state.totalTurns.clamp(0, 12), (i) {
          final done = i < state.turnNumber;
          final curr = i == state.turnNumber;
          return Container(
            width:  curr ? 10 : 6,
            height: curr ? 10 : 6,
            margin: const EdgeInsetsDirectional.only(start: 4),
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
      ],
    );
  }
}

// ─────────────────────────────────────────────
// QUESTION CARD
// Gradient: roseDeep 6% → gold 3%, 20px radius
// Context italic above, 18pt bold question
// ─────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.text,
    required this.contextHint,
  });
  final String text;
  final String contextHint;

  @override
  Widget build(BuildContext context) {
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.roseDeep.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (contextHint.isNotEmpty) ...[
            Text(contextHint,
              style: AppTypography.bodySmall.copyWith(
                color:     context.mutedText,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize:   18,
              fontWeight: FontWeight.w700,
              color:      context.onSurface,
              height:     1.45,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.04, end: 0, duration: 400.ms,
            curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────
// MULTIPLE CHOICE
// White cards, roseGradient on select, check right
// Haptic + instant select, 60ms stagger
// ─────────────────────────────────────────────

class _MCQInput extends StatelessWidget {
  const _MCQInput({
    required this.options,
    required this.selected,
    required this.isSubmitting,
    required this.onSelect,
  });
  final List<String>          options;
  final String?               selected;
  final bool                  isSubmitting;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.indexed.map((e) {
        final i   = e.$1;
        final opt = e.$2;
        final isSelected = selected == opt;

        return GestureDetector(
          onTap: isSubmitting ? null : () => onSelect(opt),
          child: AnimatedContainer(
            duration: 200.ms,
            margin:  const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isSelected ? AppColors.roseGradient : null,
              color:    isSelected ? null : context.surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : context.cardBorder,
                width: 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color:      AppColors.roseDeep.withOpacity(0.2),
                        blurRadius: 8,
                        offset:     const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(opt,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isSelected
                          ? AppColors.white
                          : context.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded,
                    color: AppColors.white, size: 20),
              ],
            ),
          ),
        )
            .animate(delay: Duration(milliseconds: i * 60))
            .fadeIn(duration: 300.ms)
            .slideX(begin: -0.04, end: 0, duration: 300.ms);
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────
// BOOLEAN (Yes / No)
// Two 72px buttons, success green / error red
// ─────────────────────────────────────────────

class _BooleanInput extends StatelessWidget {
  const _BooleanInput({
    required this.isSubmitting,
    required this.selected,
    required this.onSelect,
  });
  final bool                  isSubmitting;
  final String?               selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BoolBtn(
            label:    'Yes',
            icon:     Icons.check_circle_outline_rounded,
            color:    AppColors.success,
            selected: selected == 'yes',
            onTap:    isSubmitting ? null : () => onSelect('yes'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _BoolBtn(
            label:    'No',
            icon:     Icons.cancel_outlined,
            color:    AppColors.error,
            selected: selected == 'no',
            onTap:    isSubmitting ? null : () => onSelect('no'),
          ),
        ),
      ],
    );
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
        duration: 200.ms,
        height: 72,
        decoration: BoxDecoration(
          color:        selected ? color : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : color.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
              color: selected ? AppColors.white : color,
              size:  28),
            const SizedBox(height: 4),
            Text(label,
              style: AppTypography.labelLarge.copyWith(
                color:      selected ? AppColors.white : color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// RANKING (drag to reorder)
// White cards, 14px radius, rose circle number,
// drag handle right, elevated when dragging
// ─────────────────────────────────────────────

class _RankingInput extends StatelessWidget {
  const _RankingInput({
    required this.items,
    required this.isSubmitting,
    required this.onReorder,
    required this.onSubmit,
  });
  final List<String>                items;
  final bool                        isSubmitting;
  final void Function(List<String>) onReorder;
  final VoidCallback                onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Drag to rank from most to least important:',
          style: AppTypography.bodySmall.copyWith(
            color:     context.mutedText,
            fontStyle: FontStyle.italic,
            fontSize:  11,
          ),
        ),
        const SizedBox(height: 12),

        ReorderableListView(
          shrinkWrap: true,
          physics:    const NeverScrollableScrollPhysics(),
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (_, __) => Material(
                elevation:    8,
                borderRadius: BorderRadius.circular(14),
                shadowColor:  AppColors.roseDeep.withOpacity(0.15),
                child: Transform.rotate(
                  angle: 0.035, // ~2° tilt
                  child: child,
                ),
              ),
            );
          },
          onReorder: (oldIndex, newIndex) {
            HapticFeedback.selectionClick();
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
                color:        context.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.cardBorder.withOpacity(0.4)),
              ),
              child: ListTile(
                dense: true,
                leading: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.roseDeep.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                      style: AppTypography.labelSmall.copyWith(
                        color:      AppColors.roseDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                title: Text(item,
                  style: AppTypography.bodyMedium.copyWith(
                    color: context.onSurface),
                ),
                trailing: Icon(Icons.drag_handle_rounded,
                  color: context.mutedText, size: 20),
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
      ],
    );
  }
}

// ─────────────────────────────────────────────
// SLIDER (1-10)
// 48pt bold value, custom thumb 28px + gold border
// 6px track, min/max labels
// ─────────────────────────────────────────────

class _SliderInput extends StatelessWidget {
  const _SliderInput({
    required this.value,
    required this.label,
    required this.isSubmitting,
    required this.onChanged,
    required this.onSubmit,
  });
  final double                value;
  final String                label;
  final bool                  isSubmitting;
  final void Function(double) onChanged;
  final VoidCallback          onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Large value display
        Text(
          '${value.round()}',
          style: const TextStyle(
            fontSize:   48,
            fontWeight: FontWeight.w700,
            color:      AppColors.roseDeep,
          ),
        ),

        if (label.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(label,
            style: AppTypography.bodySmall.copyWith(
              color:     context.mutedText,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Custom slider
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor:   AppColors.roseDeep,
            inactiveTrackColor: context.subtleBg,
            thumbColor:         AppColors.roseDeep,
            overlayColor:       AppColors.roseDeep.withOpacity(0.15),
            trackHeight:        6,
            thumbShape: const _GoldBorderThumb(
              enabledThumbRadius: 14,
            ),
          ),
          child: Slider(
            value:     value,
            min:       1,
            max:       10,
            divisions: 9,
            onChanged: isSubmitting
                ? null
                : (v) {
                    HapticFeedback.selectionClick();
                    onChanged(v);
                  },
          ),
        ),

        // Min/Max labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 — Not at all',
                style: AppTypography.labelSmall.copyWith(
                  color: context.mutedText),
              ),
              Text('10 — Absolutely',
                style: AppTypography.labelSmall.copyWith(
                  color: context.mutedText),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        MiskButton(
          label:     'Submit',
          onPressed: isSubmitting ? null : onSubmit,
          loading:   isSubmitting,
          icon:      Icons.check_rounded,
        ),
      ],
    );
  }
}

/// Custom 28px thumb with gold border
class _GoldBorderThumb extends RoundSliderThumbShape {
  const _GoldBorderThumb({required double enabledThumbRadius})
      : super(enabledThumbRadius: enabledThumbRadius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    // Gold border
    canvas.drawCircle(
      center,
      enabledThumbRadius + 2,
      Paint()
        ..color = AppColors.goldPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Rose fill
    canvas.drawCircle(
      center,
      enabledThumbRadius,
      Paint()..color = sliderTheme.thumbColor ?? AppColors.roseDeep,
    );
  }
}

// ─────────────────────────────────────────────
// COMPLETION (fill-in-the-blank)
// ─────────────────────────────────────────────

class _CompletionInput extends StatelessWidget {
  const _CompletionInput({
    required this.stem,
    required this.controller,
    required this.isSubmitting,
    required this.onSubmit,
  });
  final String                stem;
  final TextEditingController controller;
  final bool                  isSubmitting;
  final VoidCallback          onSubmit;

  List<String> get _parts => stem.split('___');

  @override
  Widget build(BuildContext context) {
    final hasBlank = _parts.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasBlank) ...[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_parts[0],
                style: AppTypography.bodyLarge.copyWith(
                  color: context.onSurface, height: 1.6),
              ),
              Container(
                width: 120,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    isDense:        true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.roseDeep.withOpacity(0.3)),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.roseDeep, width: 2),
                    ),
                  ),
                  style: AppTypography.bodyLarge.copyWith(
                    color:      AppColors.roseDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_parts.length > 1)
                Text(_parts[1],
                  style: AppTypography.bodyLarge.copyWith(
                    color: context.onSurface, height: 1.6),
                ),
            ],
          ),
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
      ],
    );
  }
}

// ─────────────────────────────────────────────
// OPEN TEXT
// Multiline, min-length counter with animated
// opacity toggle, submit disabled until min met
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

  int get _remaining =>
      widget.minLength - widget.controller.text.trim().length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          maxLines:   widget.maxLines,
          minLines:   3,
          maxLength:  500,
          decoration: InputDecoration(
            hintText:  widget.hint,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: context.mutedText),
            filled:    true,
            fillColor: context.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: context.cardBorder.withOpacity(0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: context.cardBorder.withOpacity(0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.roseDeep, width: 2),
            ),
          ),
          style: AppTypography.bodyMedium.copyWith(
            color:  context.onSurface,
            height: 1.55,
          ),
        ),

        const SizedBox(height: 6),

        // Min-length counter — animated opacity
        AnimatedOpacity(
          opacity:  _remaining > 0 ? 1 : 0,
          duration: 200.ms,
          child: Text(
            '$_remaining more character${_remaining == 1 ? '' : 's'} needed',
            style: AppTypography.labelSmall.copyWith(
              color: context.mutedText),
          ),
        ),

        const SizedBox(height: 16),

        MiskButton(
          label:     'Submit answer',
          onPressed: _canSubmit ? widget.onSubmit : null,
          loading:   widget.isSubmitting,
          icon:      Icons.send_rounded,
        ),
      ],
    );
  }
}
