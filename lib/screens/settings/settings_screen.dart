import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:weathexer/models/character_profile.dart';
import 'package:weathexer/services/character_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CharacterService>(
      builder: (context, charService, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('설정',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                _buildSectionTitle(context, '캐릭터 선택'),
                const SizedBox(height: 12),
                ...charService.characters.map((character) {
                  final isSelected =
                      character.id == charService.currentCharacter.id;
                  return _buildCharacterTile(
                    character: character,
                    isSelected: isSelected,
                    onTap: () => charService.selectCharacter(
                        charService.characters.indexOf(character)),
                  );
                }),
                const SizedBox(height: 32),
                _buildSectionTitle(context, '현재 의상'),
                const SizedBox(height: 12),
                _buildOutfitInfo(charService.currentOutfit),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(title,
        style: const TextStyle(
            color: Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2));
  }

  Widget _buildCharacterTile({
    required CharacterProfile character,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E676).withOpacity(0.12)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF00E676)
                  : Colors.white.withOpacity(0.1),
              width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Text(character.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(character.name,
                      style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF00E676)
                              : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('의상 ${character.outfits.length}종',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF00E676), size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildOutfitInfo(CharacterOutfit outfit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.checkroom,
                color: Color(0xFF00E676), size: 20),
            const SizedBox(width: 8),
            Text(outfit.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _buildTag('계절', outfit.season),
            const SizedBox(width: 8),
            _buildTag('날씨', outfit.condition),
          ]),
        ],
      ),
    );
  }

  Widget _buildTag(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20)),
      child: Text('$label: $value',
          style: const TextStyle(color: Colors.white70, fontSize: 12)),
    );
  }
}