import { Module } from '@nestjs/common';
import { DatabaseModule } from './database/database.module.js';
import { HealthController } from './health/health.controller.js';
import { NotesModule } from './notes/notes.module.js';

@Module({
  imports: [DatabaseModule, NotesModule],
  controllers: [HealthController],
})
export class AppModule {}
