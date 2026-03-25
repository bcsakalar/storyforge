-- AlterTable: Chapter - add quickSummary
ALTER TABLE "chapters" ADD COLUMN "quick_summary" TEXT;

-- AlterTable: StoryEntity - add status, statusHistory, relationships
ALTER TABLE "story_entities" ADD COLUMN "status" TEXT NOT NULL DEFAULT 'active';
ALTER TABLE "story_entities" ADD COLUMN "status_history" JSONB NOT NULL DEFAULT '[]';
ALTER TABLE "story_entities" ADD COLUMN "relationships" JSONB NOT NULL DEFAULT '[]';

-- AlterTable: StoryEvent - add relevanceDecay, isResolved
ALTER TABLE "story_events" ADD COLUMN "relevance_decay" DOUBLE PRECISION NOT NULL DEFAULT 1.0;
ALTER TABLE "story_events" ADD COLUMN "is_resolved" BOOLEAN NOT NULL DEFAULT false;

-- CreateIndex: StoryEntity status index
CREATE INDEX "story_entities_story_id_status_idx" ON "story_entities"("story_id", "status");

-- CreateIndex: StoryEvent isResolved index
CREATE INDEX "story_events_story_id_is_resolved_idx" ON "story_events"("story_id", "is_resolved");

-- CreateTable: StoryLore
CREATE TABLE "story_lore" (
    "id" SERIAL NOT NULL,
    "story_id" INTEGER NOT NULL,
    "category" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "embedding" vector(768),
    "is_canon" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "story_lore_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "story_lore_story_id_category_idx" ON "story_lore"("story_id", "category");
CREATE INDEX "story_lore_story_id_is_canon_idx" ON "story_lore"("story_id", "is_canon");

-- AddForeignKey
ALTER TABLE "story_lore" ADD CONSTRAINT "story_lore_story_id_fkey" FOREIGN KEY ("story_id") REFERENCES "stories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateIndex: HNSW indexes for pgvector (Faz 3.1)
CREATE INDEX IF NOT EXISTS "idx_story_entities_embedding_hnsw" ON "story_entities"
  USING hnsw ("embedding" vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS "idx_story_events_embedding_hnsw" ON "story_events"
  USING hnsw ("embedding" vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS "idx_story_lore_embedding_hnsw" ON "story_lore"
  USING hnsw ("embedding" vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);
