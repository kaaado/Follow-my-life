/// Result type for domain operations.
/// Avoids throwing exceptions for expected business logic outcomes.
library;

import 'package:follow_my_life/core/errors/failures.dart';

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T get value => (this as Success<T>).data;
  AppFailure get failure => (this as Failure<T>).error;

  R when<R>({
    required R Function(T data) success,
    required R Function(AppFailure error) failure,
  }) {
    return switch (this) {
      Success<T>(data: final d) => success(d),
      Failure<T>(error: final e) => failure(e),
    };
  }

  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success<T>(data: final d) => Success(transform(d)),
      Failure<T>(error: final e) => Failure(e),
    };
  }
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class Failure<T> extends Result<T> {
  final AppFailure error;
  const Failure(this.error);
}
