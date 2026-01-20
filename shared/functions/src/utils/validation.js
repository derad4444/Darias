// src/utils/validation.js

const {ErrorTypes} = require("./errorHandler");

/**
 * バリデーションユーティリティ
 */
class Validator {
  /**
   * 必須フィールドの検証
   */
  static validateRequired(value, fieldName) {
    if (value === undefined || value === null || value === "") {
      throw ErrorTypes.ValidationError(`${fieldName} is required`);
    }
    return value;
  }

  /**
   * 文字列の検証
   */
  static validateString(value, fieldName, options = {}) {
    this.validateRequired(value, fieldName);

    if (typeof value !== "string") {
      throw ErrorTypes.ValidationError(`${fieldName} must be a string`);
    }

    if (options.minLength && value.length < options.minLength) {
      throw ErrorTypes.ValidationError(
          `${fieldName} must be at least ${options.minLength} characters long`,
      );
    }

    if (options.maxLength && value.length > options.maxLength) {
      throw ErrorTypes.ValidationError(
          `${fieldName} must be at most ${options.maxLength} characters long`,
      );
    }

    if (options.pattern && !options.pattern.test(value)) {
      throw ErrorTypes.ValidationError(`${fieldName} format is invalid`);
    }

    return value.trim();
  }

  /**
   * オブジェクトの検証
   */
  static validateObject(value, fieldName) {
    this.validateRequired(value, fieldName);

    if (typeof value !== "object" || Array.isArray(value)) {
      throw ErrorTypes.ValidationError(`${fieldName} must be an object`);
    }

    return value;
  }

  /**
   * 配列の検証
   */
  static validateArray(value, fieldName, options = {}) {
    this.validateRequired(value, fieldName);

    if (!Array.isArray(value)) {
      throw ErrorTypes.ValidationError(`${fieldName} must be an array`);
    }

    if (options.minLength && value.length < options.minLength) {
      throw ErrorTypes.ValidationError(
          `${fieldName} must have at least ${options.minLength} items`,
      );
    }

    if (options.maxLength && value.length > options.maxLength) {
      throw ErrorTypes.ValidationError(
          `${fieldName} must have at most ${options.maxLength} items`,
      );
    }

    return value;
  }

  /**
   * CharacterIDの検証
   */
  static validateCharacterId(characterId) {
    return this.validateString(characterId, "characterId", {
      minLength: 1,
      maxLength: 100,
    });
  }

  /**
   * UserIDの検証
   */
  static validateUserId(userId) {
    return this.validateString(userId, "userId", {
      minLength: 1,
      maxLength: 100,
    });
  }

  /**
   * テキストメッセージの検証
   */
  static validateMessage(message) {
    return this.validateString(message, "message", {
      minLength: 1,
      maxLength: 1000,
    });
  }

  /**
   * リクエストボディの基本検証
   */
  static validateRequestBody(req, requiredFields = []) {
    if (!req.body) {
      throw ErrorTypes.ValidationError("Request body is required");
    }

    const body = this.validateObject(req.body, "request body");

    for (const field of requiredFields) {
      this.validateRequired(body[field], field);
    }

    return body;
  }

  /**
   * Firebase Functions onCall リクエストの検証
   */
  static validateCallRequest(req, requiredFields = []) {
    if (!req.data) {
      throw ErrorTypes.ValidationError("Request data is required");
    }

    const data = this.validateObject(req.data, "request data");

    for (const field of requiredFields) {
      this.validateRequired(data[field], field);
    }

    return data;
  }
}

module.exports = {Validator};
