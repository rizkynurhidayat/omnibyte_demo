import 'package:flutter/material.dart';
import '../../../chat/presentation/pages/chat_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../../ekyc/presentation/pages/ekyc_page.dart';
import '../../../../ekyc/presentation/bloc/ekyc_bloc.dart';
import '../../../../ekyc/domain/entities/document_type.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withAlpha(26), // soft primary tint
              theme.colorScheme.surface,
              theme.colorScheme.secondary.withAlpha(13), // soft secondary tint
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Welcome header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, User!',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Selamat datang di OmniByte Demo',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodyMedium?.color?.withAlpha(150),
                          ),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withAlpha(30),
                      radius: 24,
                      child: Icon(
                        Icons.person,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Info banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, theme.colorScheme.primary.withAlpha(200)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withAlpha(60),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.security, color: Colors.white, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        'Demo Biometrik & Identitas',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pindai wajah dan kartu identitas dengan teknologi OCR dan Deteksi Keaktifan (Liveness)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withAlpha(220),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                Text(
                  'Fitur Utama',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Navigation menu cards
                // _buildMenuCard(
                //   context,
                //   title: 'e-KYC KTP',
                //   subtitle: 'Pindai KTP & verifikasi identitas wajah',
                //   icon: Icons.credit_card,
                //   color: theme.colorScheme.primary,
                //   onTap: () {
                //     Navigator.push(
                //       context,
                //       MaterialPageRoute(
                //         builder: (context) => BlocProvider(
                //           create: (context) => sl<EkycBloc>(),
                //           child: const EkycPage(documentType: DocumentType.ktp),
                //         ),
                //       ),
                //     );
                //   },
                // ),
                // const SizedBox(height: 16),
                // _buildMenuCard(
                //   context,
                //   title: 'e-KYC SIM',
                //   subtitle: 'Pindai SIM & verifikasi identitas wajah',
                //   icon: Icons.badge_outlined,
                //   color: theme.colorScheme.primary,
                //   onTap: () {
                //     Navigator.push(
                //       context,
                //       MaterialPageRoute(
                //         builder: (context) => BlocProvider(
                //           create: (context) => sl<EkycBloc>(),
                //           child: const EkycPage(documentType: DocumentType.sim),
                //         ),
                //       ),
                //     );
                //   },
                // ),
                // const SizedBox(height: 16),
                // _buildMenuCard(
                //   context,
                //   title: 'e-KYC Passport',
                //   subtitle: 'Pindai Passport & verifikasi identitas wajah',
                //   icon: Icons.flight_takeoff,
                //   color: theme.colorScheme.primary,
                //   onTap: () {
                //     Navigator.push(
                //       context,
                //       MaterialPageRoute(
                //         builder: (context) => BlocProvider(
                //           create: (context) => sl<EkycBloc>(),
                //           child: const EkycPage(documentType: DocumentType.passport),
                //         ),
                //       ),
                //     );
                //   },
                // ),
                _buildMenuCard(
                  context,
                  title: 'e-KYC Auto Detect',
                  subtitle: 'Auto deteksi KTP, SIM, atau Passport via OCR',
                  icon: Icons.document_scanner,
                  color: theme.colorScheme.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BlocProvider(
                          create: (context) => sl<EkycBloc>(),
                          child: const EkycPage(documentType: DocumentType.auto),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildMenuCard(
                  context,
                  title: 'Customer Service Chat',
                  subtitle: 'Simulasi obrolan bantuan layanan',
                  icon: Icons.chat_bubble_outline,
                  color: theme.colorScheme.secondary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChatPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withAlpha(180),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
