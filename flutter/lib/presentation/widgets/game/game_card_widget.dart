import 'package:flutter/material.dart';
import 'package:darias/data/models/game/game_models.dart';
import 'package:darias/presentation/widgets/character/element_effect_widget.dart';

class GameCardWidget extends StatelessWidget {
  final GameCard card;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onTap;

  const GameCardWidget({
    super.key,
    required this.card,
    this.isSelected = false,
    this.isDisabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = card.element.color;
    final rarityGlow = switch (card.rarity) {
      CardRarity.rare     => color.withOpacity(0.9),
      CardRarity.uncommon => color.withOpacity(0.6),
      CardRarity.common   => color.withOpacity(0.3),
    };

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 62,
        height: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(isSelected ? 0.9 : 0.5),
              Colors.black87,
            ],
          ),
          border: Border.all(
            color: isSelected ? color : Colors.white24,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: rarityGlow, blurRadius: 14, spreadRadius: 2)]
              : null,
        ),
        child: Stack(
          children: [
            // レアリティマーク
            if (card.rarity != CardRarity.common)
              Positioned(
                top: 4,
                right: 4,
                child: Text(
                  card.rarity == CardRarity.rare ? '★' : '◆',
                  style: TextStyle(
                    fontSize: 8,
                    color: card.rarity == CardRarity.rare
                        ? Colors.amber
                        : Colors.white54,
                  ),
                ),
              ),

            // 属性アイコン
            Positioned(
              top: 5,
              left: 5,
              child: Text(
                _elementIcon(card.element),
                style: const TextStyle(fontSize: 14),
              ),
            ),

            // カード名
            Positioned(
              bottom: 22,
              left: 0,
              right: 0,
              child: Text(
                card.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // パワー
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PWR ${'⬡' * card.power}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 7,
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
              ),
            ),

            if (isDisabled)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _elementIcon(ElementType element) {
  return switch (element) {
    ElementType.fire    => '🔥',
    ElementType.water   => '💧',
    ElementType.wind    => '🌀',
    ElementType.earth   => '🪨',
    ElementType.ice     => '❄️',
    ElementType.thunder => '⚡',
    ElementType.light   => '✨',
    ElementType.dark    => '🌑',
    ElementType.none    => '⭕',
  };
}
