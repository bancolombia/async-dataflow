import { Component, OnDestroy, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatIconModule } from '@angular/material/icon';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatChipEditedEvent, MatChipInputEvent, MatChipsModule } from '@angular/material/chips';
import { MatCardModule } from '@angular/material/card';
import { MatSelectModule } from '@angular/material/select';
import { MatSnackBar, MatSnackBarModule } from '@angular/material/snack-bar';
import { SettingsService } from '../../services/settings.service';
import { Settings } from '../../models/settings.interface';
import { COMMA, ENTER } from '@angular/cdk/keycodes';
import { environment } from '../../environments/environment';

@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [CommonModule, FormsModule, MatButtonModule, MatFormFieldModule, MatInputModule, MatCardModule, MatIconModule, MatChipsModule, MatCheckboxModule, MatSnackBarModule, MatSelectModule],
  templateUrl: './settings.component.html',
  styleUrl: './settings.component.css'
})
export class SettingsComponent implements OnInit, OnDestroy {
  readonly separatorKeysCodes = [ENTER, COMMA] as const;
  readonly addOnBlur = true;
  readonly allowedTransports = ['ws', 'sse'];
  settings?: Settings;
  readonly servers = Object.keys(environment.servers);

  constructor(private settingsProvider: SettingsService, private snackbar: MatSnackBar) { }

  ngOnInit(): void {
    this.settings = this.settingsProvider.load();
  }

  ngOnDestroy(): void {
    this.save();
  }

  save() {
    if (this.settings) {
      this.settingsProvider.save(this.settings);
      this.snackbar.open('Settings saved', 'Close', { duration: 2000 });
    }
  }

  remove(transport: string) {
    if (this.settings) {
      this.settings.transports = this.settings.transports.filter(t => t !== transport);
    }
  }

  add(event: MatChipInputEvent) {
    if (this.settings) {
      const transport = event.value.trim();
      if (transport && this.allowedTransports.includes(transport)) {
        this.settings.transports.push(transport);
      }
    }
  }

  edit(transport: string, event: MatChipEditedEvent) {
    if (this.settings) {
      const newTransport = event.value.trim();
      if (transport && this.allowedTransports.includes(transport)) {
        this.settings.transports = this.settings.transports.map(t => t === transport ? newTransport : t);
      }
    }
  }

}
