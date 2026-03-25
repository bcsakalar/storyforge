const fs = require('fs');
const path = require('path');

describe('story page template', () => {
  it('should keep escaped newline patterns inside the inline normalizeStoryText script', () => {
    const templatePath = path.join(__dirname, '../../../src/views/pages/story.ejs');
    const template = fs.readFileSync(templatePath, 'utf8');

    expect(template).toContain("replace(/\\\\r\\\\n/g, '\\\\n')");
    expect(template).toContain("replace(/\\\\s*\\\\*\\\\*\\\\*\\\\s*/g, '\\\\n***\\\\n')");
    expect(template).toContain("split(/\\\\n\\\\*\\\\*\\\\*\\\\n/)");
    expect(template).toContain("join('\\\\n\\\\n')");
    expect(template).toContain("join('\\\\n***\\\\n')");
  });
});