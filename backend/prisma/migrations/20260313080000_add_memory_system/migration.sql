-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- CreateTable: story_entities (RAG Memory - Characters, Locations, Objects)
CREATE TABLE "story_entities" (
    "id" SERIAL NOT NULL,
    "story_id" INTEGER NOT NULL,
    "type" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "attributes" JSONB NOT NULL DEFAULT '{}',
    "embedding" vector(768),
    "first_seen" INTEGER NOT NULL DEFAULT 1,
    "last_seen" INTEGER NOT NULL DEFAULT 1,
    "importance" DOUBLE PRECISION NOT NULL DEFAULT 0.5,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "story_entities_pkey" PRIMARY KEY ("id")
);

-- CreateTable: story_events (RAG Memory - Important Plot Events)
CREATE TABLE "story_events" (
    "id" SERIAL NOT NULL,
    "story_id" INTEGER NOT NULL,
    "chapter_num" INTEGER NOT NULL,
    "description" TEXT NOT NULL,
    "impact" TEXT NOT NULL DEFAULT 'minor',
    "entities" TEXT[],
    "embedding" vector(768),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "story_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable: story_world_states (World State Snapshots)
CREATE TABLE "story_world_states" (
    "id" SERIAL NOT NULL,
    "story_id" INTEGER NOT NULL,
    "chapter_num" INTEGER NOT NULL,
    "state" JSONB NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "story_world_states_pkey" PRIMARY KEY ("id")
);

-- CreateTable: token_usage (Cost Tracking)
CREATE TABLE "token_usage" (
    "id" SERIAL NOT NULL,
    "user_id" INTEGER NOT NULL,
    "story_id" INTEGER,
    "model" TEXT NOT NULL DEFAULT 'gemini-3-flash-preview',
    "input_tokens" INTEGER NOT NULL DEFAULT 0,
    "output_tokens" INTEGER NOT NULL DEFAULT 0,
    "operation" TEXT NOT NULL DEFAULT 'generate',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "token_usage_pkey" PRIMARY KEY ("id")
);

-- CreateIndex: story_entities
CREATE UNIQUE INDEX "story_entities_story_id_type_name_key" ON "story_entities"("story_id", "type", "name");
CREATE INDEX "story_entities_story_id_type_idx" ON "story_entities"("story_id", "type");
CREATE INDEX "story_entities_story_id_importance_idx" ON "story_entities"("story_id", "importance");

-- CreateIndex: story_events
CREATE INDEX "story_events_story_id_chapter_num_idx" ON "story_events"("story_id", "chapter_num");
CREATE INDEX "story_events_story_id_impact_idx" ON "story_events"("story_id", "impact");

-- CreateIndex: story_world_states
CREATE UNIQUE INDEX "story_world_states_story_id_chapter_num_key" ON "story_world_states"("story_id", "chapter_num");

-- CreateIndex: token_usage
CREATE INDEX "token_usage_user_id_created_at_idx" ON "token_usage"("user_id", "created_at");
CREATE INDEX "token_usage_story_id_idx" ON "token_usage"("story_id");

-- AddForeignKey
ALTER TABLE "story_entities" ADD CONSTRAINT "story_entities_story_id_fkey" FOREIGN KEY ("story_id") REFERENCES "stories"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "story_events" ADD CONSTRAINT "story_events_story_id_fkey" FOREIGN KEY ("story_id") REFERENCES "stories"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "story_world_states" ADD CONSTRAINT "story_world_states_story_id_fkey" FOREIGN KEY ("story_id") REFERENCES "stories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateIndex: HNSW indexes for vector similarity search (fast approximate nearest neighbor)
CREATE INDEX "story_entities_embedding_idx" ON "story_entities" USING hnsw ("embedding" vector_cosine_ops);
CREATE INDEX "story_events_embedding_idx" ON "story_events" USING hnsw ("embedding" vector_cosine_ops);
