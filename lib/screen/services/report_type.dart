import 'package:flutter/material.dart';

class ReportType {
  final String name;
  final IconData icon;
  final String shortDescription;
  // final String details;

  const ReportType({
    required this.name,
    required this.icon,
    required this.shortDescription,
    // required this.details,
  });
}

class ReportTypes {
  static const List<ReportType> all = [
    ReportType(
      name: "Scam",
      icon: Icons.warning_amber_rounded,
      shortDescription:
          "Fraud calls/messages asking for money or sensitive information.",
      // details:
      //     "Scammers often pretend to be trusted individuals or organizations to steal money, OTP codes, passwords, or banking information.\n\n"
      //     "Common signs:\n"
      //     "• Urgent payment requests\n"
      //     "• Suspicious links\n"
      //     "• Asking for OTP or passwords\n"
      //     "• Threatening language",
    ),
    ReportType(
      name: "Silent Call",
      icon: Icons.phone_disabled_rounded,
      shortDescription:
          "Calls with no response or immediate hang up after answering.",
      // details:
      //     "Silent calls are commonly used to check whether a phone number is active.\n\n"
      //     "Common signs:\n"
      //     "• No voice after answering\n"
      //     "• Caller hangs up immediately\n"
      //     "• Repeated calls from unknown numbers\n"
      //     "• Background static noises",
    ),
    ReportType(
      name: "Impersonation",
      icon: Icons.account_circle_rounded,
      shortDescription:
          "Pretending to be police, bank staff or government officers.",
      // details:
      //     "Impersonation scams manipulate victims by pretending to be trusted authorities.\n\n"
      //     "Common signs:\n"
      //     "• Fake police or bank calls\n"
      //     "• Requests for verification codes\n"
      //     "• Threats of arrest or account suspension\n"
      //     "• Asking for money transfers",
    ),
    ReportType(
      name: "Robocall",
      icon: Icons.smartphone_rounded,
      shortDescription:
          "Automated call that delivers a pre-recorded or artificial voice message.",
      // details:
      //     "In many scam cases, robocalls are designed to pressure victims into pressing buttons, calling back, or providing personal information.\n\n"
      //     "Common signs:\n"
      //     "• \n"
      //     "• Pre-recorded voice instead of a real person\n"
      //     "• Asking you to press a number (e.g., “Press 1 to speak to an officer”)\n"
      //     "• Claims of urgent issues like bank problems, tax issues, or unpaid bills\n"
      //     "• Calls from unknown or international numbers\n"
      //     "• Repeated automated calls in a short time\n"
      //     "• Robotic or unnatural speech tone",
    ),
  ];
}
