import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../config/theme.dart';

class MarkdownTableCardBuilder extends MarkdownElementBuilder {
  final BuildContext context;

  MarkdownTableCardBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // The top-level element is typically a <table> containing <thead> and <tbody>
    if (element.tag != 'table') return null;

    List<String> headers = [];
    List<List<String>> rows = [];

    // Simple parser for the markdown AST structure of a table
    for (var child in element.children ?? []) {
      if (child is md.Element) {
        if (child.tag == 'thead') {
          for (var tr in child.children ?? []) {
            if (tr is md.Element && tr.tag == 'tr') {
              for (var th in tr.children ?? []) {
                if (th is md.Element && th.tag == 'th') {
                  headers.add(th.textContent);
                }
              }
            }
          }
        } else if (child.tag == 'tbody') {
          for (var tr in child.children ?? []) {
            if (tr is md.Element && tr.tag == 'tr') {
              List<String> rowCells = [];
              for (var td in tr.children ?? []) {
                if (td is md.Element && td.tag == 'td') {
                  rowCells.add(td.textContent);
                }
              }
              if (rowCells.isNotEmpty) {
                rows.add(rowCells);
              }
            }
          }
        }
      }
    }

    if (headers.isEmpty || rows.isEmpty) {
      return null; // Fallback to default rendering if parsing fails
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows.map((row) => _buildCard(headers, row)).toList(),
    );
  }

  Widget _buildCard(List<String> headers, List<String> cells) {
    // Ensure we don't go out of bounds if rows have fewer cells than headers
    int cellCount = cells.length;

    // Use the first column as the primary title of the card
    String title = cellCount > 0 ? cells[0] : 'Data';

    // Build the remaining stats dynamically based on the headers
    List<Widget> statWidgets = [];
    for (int i = 1; i < headers.length; i++) {
      if (i < cellCount) {
        String header = headers[i];
        String value = cells[i];

        bool isStatus = header.toLowerCase().contains('status') || header.toLowerCase().contains('trend');

        statWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  header,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.nc.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                isStatus
                    ? _buildStatusPill(value)
                    : Flexible(
                        child: Text(
                          value,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            color: context.nc.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        );
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.nc.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary Title (from first column)
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.nc.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: context.nc.divider),
          const SizedBox(height: 12),
          // Remaining mapped stats
          ...statWidgets,
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    String lowerStatus = status.toLowerCase();
    Color bgColor = context.nc.inputFill;
    Color textColor = context.nc.textSecondary;

    if (lowerStatus.contains('low') || lowerStatus.contains('high') || lowerStatus.contains('elevated')) {
      bgColor = const Color(0xFFFEF2F2);
      textColor = const Color(0xFFEF4444);
    } else if (lowerStatus.contains('optimal') || lowerStatus.contains('normal') || lowerStatus.contains('good')) {
      bgColor = const Color(0xFFF0FDF4);
      textColor = const Color(0xFF22C55E);
    } else if (lowerStatus.contains('warning') || lowerStatus.contains('suboptimal')) {
      bgColor = const Color(0xFFFEFCE8);
      textColor = const Color(0xFFEAB308);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
