import 'package:DigiDoc/screens/security.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/color_app.dart';
import '../services/current_state_processing.dart';
import 'about_app.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<CurrentStateProcessing>(context);
    String _theme = themeProvider.isDarkMode ? 'Escuro' : 'Padrão';

    return Scaffold(
      body: Container(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkBackground
            : AppColors.background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    children: [
                      Card(
                        elevation: 2,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkCardBackground
                            : AppColors.cardBackground,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          title: Text(
                            'Segurança',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.primaryGradientStart,
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.calmWhite
                                : AppColors.primaryGradientStart,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const SecurityScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 2,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkCardBackground
                            : AppColors.cardBackground,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          title: Text(
                            'Aparência',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.primaryGradientStart,
                            ),
                          ),
                          trailing: DropdownButton<String>(
                            value: _theme,
                            dropdownColor: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkCardBackground
                                : AppColors.cardBackground,
                            style: GoogleFonts.poppins(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.primaryGradientStart,
                              fontSize: 14,
                            ),
                            iconEnabledColor: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.calmWhite
                                : AppColors.primaryGradientStart,
                            items: ['Padrão', 'Escuro'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: GoogleFonts.poppins(
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? AppColors.calmWhite
                                        : AppColors.primaryGradientStart,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                themeProvider.toggleTheme(newValue == 'Escuro');
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 2,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkCardBackground
                            : AppColors.cardBackground,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          title: Text(
                            'Sobre a Aplicação',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.primaryGradientStart,
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.calmWhite
                                : AppColors.primaryGradientStart,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AboutAppScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}