import { GameViewModel } from '../viewmodels/GameViewModel';

// The Ability owns the application-scoped controller. Pages never construct a second save writer.
export class Session {
  static vm: GameViewModel | undefined = undefined;
  static startupError: string = '';
}
