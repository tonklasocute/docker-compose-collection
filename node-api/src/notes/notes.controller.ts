import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Res,
} from '@nestjs/common';
import type { Response } from 'express';
import { CreateNoteDto, ListNotesQuery, UpdateNoteDto } from './notes.dto.js';
import { NotesService } from './notes.service.js';

@Controller('notes')
export class NotesController {
  constructor(private readonly notes: NotesService) {}

  @Get()
  async list(@Query() q: ListNotesQuery) {
    return { items: await this.notes.list(q.limit, q.offset), limit: q.limit, offset: q.offset };
  }

  @Get(':id')
  async get(@Param('id', ParseIntPipe) id: number, @Res({ passthrough: true }) res: Response) {
    const { note, cache } = await this.notes.get(id);
    res.setHeader('X-Cache', cache);
    return note;
  }

  @Post()
  create(@Body() dto: CreateNoteDto) {
    return this.notes.create(dto);
  }

  @Patch(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateNoteDto) {
    if (dto.title === undefined && dto.body === undefined) {
      throw new BadRequestException('nothing to update: send title and/or body');
    }
    return this.notes.update(id, dto);
  }

  @Delete(':id')
  @HttpCode(204)
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.notes.remove(id);
  }
}
