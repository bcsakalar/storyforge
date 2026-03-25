module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.test.js'],
  collectCoverageFrom: ['src/services/**/*.js', 'src/middleware/**/*.js'],
  modulePathIgnorePatterns: ['node_modules'],
  clearMocks: true,
};
