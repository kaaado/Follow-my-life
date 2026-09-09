/// Domain-level failure types.
/// These provide user-friendly error messages for financial operations.
library;

abstract class AppFailure {
  final String message;
  final String? details;

  const AppFailure(this.message, {this.details});

  @override
  String toString() => 'AppFailure: $message${details != null ? ' ($details)' : ''}';
}

class DatabaseFailure extends AppFailure {
  const DatabaseFailure([super.message = 'A database error occurred.', String? details])
      : super(details: details);
}

class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

class InsufficientFundsFailure extends AppFailure {
  final int available;
  final int required_;

  const InsufficientFundsFailure({
    required this.available,
    required this.required_,
  }) : super("You don't have enough available money in this source.");
}

class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'The requested item was not found.']);
}

class DuplicateFailure extends AppFailure {
  const DuplicateFailure([super.message = 'This item already exists.']);
}

class BackupFailure extends AppFailure {
  const BackupFailure(super.message);
}

class SecurityFailure extends AppFailure {
  const SecurityFailure([super.message = 'A security error occurred.']);
}

class TransactionFailure extends AppFailure {
  const TransactionFailure(super.message);
}
