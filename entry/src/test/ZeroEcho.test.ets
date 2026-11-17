import { describe, it, expect } from '@ohos/hypium';
import { ConditionGroup, GameState, cloneState, createInitialState } from '../main/ets/models/Models';
import { createStory, validateStory } from '../main/ets/data/StoryRepository';
import { Profile, SaveRepository } from '../main/ets/data/SaveRepository';
import { GameEngine } from '../main/ets/domain/GameEngine';
import { resolveEnding, explainEnding } from '../main/ets/domain/EndingResolver';
import { evaluateConditions } from '../main/ets/domain/ConditionEvaluator';
import { validateState } from '../main/ets/domain/StateValidator';
import { GameViewModel } from '../main/ets/viewmodels/GameViewModel';
import { FakeTextStore, FixedClock, TestRig, ViewModelRig, cabinetRig, choiceAction,
  completeEvidenceRig, insufficientEvidenceRig, partialEvidenceRig, puzzleAction, rawSave } from './TestSupport';

export default function zeroEchoTest(): void {
  describe('ZeroEchoProductionLogic', (): void => {
    it('T01_initial_state', 0, (): void => {
      const rig = new TestRig();
      expect(rig.state.currentNodeId).assertEqual('N01');
      expect(rig.state.remainingActions).assertEqual(18);
      expect(rig.state.trust).assertEqual(50);
      expect(rig.state.clueIds.length).assertEqual(0);
      expect(rig.state.solvedPuzzleIds.length).assertEqual(0);
      expect(rig.state.history.length).assertEqual(0);
      expect(rig.state.revision).assertEqual(0);
    });

    it('T02_share_is_one_immutable_transition', 0, (): void => {
      const rig = new TestRig();
      const original = JSON.stringify(rig.state);
      const result = rig.engine.dispatch(rig.state, choiceAction(rig.state, 'share'));
      expect(result.ok).assertTrue();
      expect(JSON.stringify(rig.state)).assertEqual(original);
      expect(result.state.remainingActions).assertEqual(17);
      expect(result.state.trust).assertEqual(60);
      expect(result.state.currentNodeId).assertEqual('N02');
      expect(result.state.history.length).assertEqual(1);
      expect(result.state.history[0].actionId).assertEqual('share');
      expect(result.state.history[0].trustDelta).assertEqual(10);
      expect(result.state.revision).assertEqual(1);
    });

    it('T03_cabinet_answer_saves_actual_reward', 0, async (): Promise<void> => {
      const rig = new ViewModelRig();
      await rig.start();
      await rig.choose('share'); await rig.choose('take-note'); await rig.choose('note-to-cabinet');
      const before = rig.vm.state.remainingActions;
      await rig.vm.act(puzzleAction(rig.vm.state, 'P01', '0417'));
      expect(rig.vm.state.solvedPuzzleIds.includes('P01')).assertTrue();
      expect(rig.vm.state.clueIds.includes('CL02')).assertTrue();
      expect(rig.vm.state.remainingActions).assertEqual(before - 1);
      const saved = await rig.repository.load('auto');
      expect(saved.status).assertEqual('valid');
      expect(JSON.stringify(saved.state)).assertEqual(JSON.stringify(rig.vm.state));
      expect(saved.savedAt).assertEqual('2026-11-16T12:00:00.000Z');
    });

    it('T04_timeline_checks_time_and_business_order', 0, (): void => {
      const rig = cabinetRig();
      rig.solve('P01', '0417');
      rig.choices(['work-alone', 'alone-to-hub', 'take-calibration', 'calibration-back',
        'take-gateway', 'gateway-back', 'open-timeline']);
      rig.solve('P02', '00:00', 'person-first');
      expect(rig.state.solvedPuzzleIds.includes('P02')).assertFalse();
      const before = rig.state.remainingActions;
      rig.solve('P02', '00:00', 'task-first');
      expect(rig.state.clueIds.includes('CL06')).assertTrue();
      expect(rig.state.solvedPuzzleIds.includes('P02')).assertTrue();
      expect(rig.state.remainingActions).assertEqual(before - 1);
      expect(rig.state.currentNodeId).assertEqual('N13');
    });

    it('T05_complete_truth_has_real_explanation', 0, (): void => {
      const rig = completeEvidenceRig();
      rig.choose('submit');
      expect(rig.state.endingId).assertEqual('E01');
      expect(explainEnding(rig.state).join(' ')).assertContain('60');
      expect(explainEnding(rig.state).join(' ')).assertContain('两个谜题');
    });

    it('T06_partial_repair_from_legal_route', 0, (): void => {
      const rig = partialEvidenceRig();
      rig.choose('submit');
      expect(rig.state.endingId).assertEqual('E02');
      expect(rig.state.clueIds.includes('CL05')).assertTrue();
      expect(rig.state.solvedPuzzleIds.includes('P02')).assertFalse();
    });

    // T07 is reserved for device process termination/relaunch and is never reported as a Mock test pass.
    it('T08_new_game_keeps_unlocked_endings', 0, async (): Promise<void> => {
      const rig = new ViewModelRig();
      const finished = completeEvidenceRig(); finished.choose('submit');
      expect((await rig.repository.save('auto', finished.state)).ok).assertTrue();
      await rig.vm.initialize();
      expect(rig.vm.profile.unlockedEndingIds.includes('E01')).assertTrue();
      await rig.vm.newGame();
      expect(rig.vm.state.currentNodeId).assertEqual('N01');
      expect(rig.vm.state.remainingActions).assertEqual(18);
      expect(rig.vm.state.clueIds.length).assertEqual(0);
      expect(rig.vm.profile.unlockedEndingIds.includes('E01')).assertTrue();
      expect((await rig.repository.loadProfile()).profile.unlockedEndingIds.includes('E01')).assertTrue();
    });

    it('T09_trust_59_60_boundary', 0, (): void => {
      const state = completeEvidenceRig().state;
      state.trust = 59;
      expect(resolveEnding(state, true, 'submit').endingId).assertEqual('E02');
      state.trust = 60;
      expect(resolveEnding(state, true, 'submit').endingId).assertEqual('E01');
      expect(resolveEnding(state, false, 'submit').endingId).assertEqual('');
    });

    it('T10_trust_clamped_at_100_and_zero', 0, (): void => {
      const high = new TestRig(); high.state.trust = 95; high.choose('share');
      expect(high.state.trust).assertEqual(100);
      expect(high.state.history[0].trustDelta).assertEqual(5);
      const low = new TestRig(); low.state.trust = 5; low.choose('accuse');
      expect(low.state.trust).assertEqual(0);
      expect(low.state.history[0].trustDelta).assertEqual(-5);
    });

    it('T11_last_paid_action_prioritizes_exhaustion', 0, (): void => {
      const rig = new TestRig(); rig.state.remainingActions = 1; rig.choose('share');
      expect(rig.state.remainingActions).assertEqual(0);
      expect(rig.state.endingId).assertEqual('E03');
      expect(rig.state.currentNodeId).assertEqual('E03');
      const before = JSON.stringify(rig.state);
      expect(rig.engine.dispatch(rig.state, choiceAction(rig.state, 'share')).ok).assertFalse();
      expect(JSON.stringify(rig.state)).assertEqual(before);
    });

    it('T12_one_action_can_submit_at_zero_cost', 0, (): void => {
      const rig = completeEvidenceRig(); rig.state.remainingActions = 1; rig.choose('submit');
      expect(rig.state.endingId).assertEqual('E01');
      expect(rig.state.remainingActions).assertEqual(1);
      expect(rig.state.history[rig.state.history.length - 1].cost).assertEqual(0);
    });

    it('T13_repeat_clue_and_solved_puzzle_do_not_reward', 0, (): void => {
      const rig = cabinetRig();
      rig.choose('cabinet-back');
      let before = JSON.stringify(rig.state);
      const duplicateClue = rig.engine.dispatch(rig.state, choiceAction(rig.state, 'take-note'));
      expect(duplicateClue.ok).assertFalse();
      expect(JSON.stringify(rig.state)).assertEqual(before);
      rig.choose('skip-note'); rig.solve('P01', '0417');
      rig.choices(['work-alone', 'alone-to-hub', 'revisit-cabinet']);
      before = JSON.stringify(rig.state);
      const duplicatePuzzle = rig.engine.dispatch(rig.state, puzzleAction(rig.state, 'P01', '0417'));
      expect(duplicatePuzzle.ok).assertFalse();
      expect(JSON.stringify(rig.state)).assertEqual(before);
      expect(rig.state.clueIds.filter((id: string): boolean => id === 'CL02').length).assertEqual(1);
    });

    it('T14_stale_revision_and_concurrent_click_apply_once', 0, async (): Promise<void> => {
      const engineRig = new TestRig();
      const stale = choiceAction(engineRig.state, 'share');
      engineRig.choose('share');
      const rejected = engineRig.engine.dispatch(engineRig.state, stale);
      expect(rejected.ok).assertFalse(); expect(rejected.error).assertEqual('STALE_ACTION');
      const rig = new ViewModelRig(); await rig.start();
      rig.store.holdWrites();
      const action = choiceAction(rig.vm.state, 'share');
      const first = rig.vm.act(action);
      await rig.vm.act(action);
      expect(rig.vm.busy).assertTrue();
      expect(rig.vm.state.revision).assertEqual(0);
      rig.store.releaseWrites(); await first;
      expect(rig.vm.state.revision).assertEqual(1);
      expect(rig.vm.state.remainingActions).assertEqual(17);
      expect(rig.vm.state.history.length).assertEqual(1);
    });

    it('T15_manual_overwrite_requires_confirmation', 0, async (): Promise<void> => {
      const rig = new ViewModelRig(); await rig.start();
      await rig.vm.saveManual('1', false);
      const original = await rig.repository.load('1');
      await rig.choose('share');
      await rig.vm.saveManual('1', false);
      expect(JSON.stringify((await rig.repository.load('1')).state)).assertEqual(JSON.stringify(original.state));
      expect(rig.vm.error).assertContain('确认覆盖');
      await rig.vm.saveManual('1', true);
      expect((await rig.repository.load('1')).state.revision).assertEqual(1);
      expect((await rig.repository.load('2')).status).assertEqual('empty');
      expect((await rig.repository.load('auto')).state.revision).assertEqual(1);
    });

    it('T16_invalid_cabinet_format_never_costs_an_action', 0, (): void => {
      const rig = cabinetRig();
      const before = JSON.stringify(rig.state);
      ['', ' ', 'abc', '417', '０４１７', '0417 '].forEach((answer: string): void => {
        const result = rig.engine.dispatch(rig.state, puzzleAction(rig.state, 'P01', answer));
        expect(result.ok).assertFalse();
        expect(JSON.stringify(result.state)).assertEqual(before);
      });
    });

    it('T17_valid_wrong_answer_costs_once_without_reward', 0, (): void => {
      const rig = cabinetRig(); const before = rig.state.remainingActions;
      rig.solve('P01', '1111');
      expect(rig.state.remainingActions).assertEqual(before - 1);
      expect(rig.state.attempts[0].count).assertEqual(1);
      expect(rig.state.solvedPuzzleIds.length).assertEqual(0);
      expect(rig.state.clueIds.includes('CL02')).assertFalse();
      expect(rig.state.currentNodeId).assertEqual('N04');
    });

    it('T18_bad_reference_or_locked_condition_is_rejected', 0, (): void => {
      const rig = new TestRig();
      let before = JSON.stringify(rig.state);
      expect(rig.engine.dispatch(rig.state, choiceAction(rig.state, 'missing-choice')).ok).assertFalse();
      expect(JSON.stringify(rig.state)).assertEqual(before);
      rig.choices(['hold', 'skip-note', 'skip-cabinet']);
      before = JSON.stringify(rig.state);
      const locked = rig.engine.dispatch(rig.state, choiceAction(rig.state, 'cooperate'));
      expect(locked.ok).assertFalse(); expect(locked.error).assertEqual('CHOICE_LOCKED');
      expect(JSON.stringify(rig.state)).assertEqual(before);
      rig.state.currentNodeId = 'missing-node';
      expect(rig.engine.dispatch(rig.state, choiceAction(rig.state, 'share')).error).assertEqual('INVALID_NODE');
    });

    it('T19_corrupt_json_types_and_ranges_are_rejected', 0, async (): Promise<void> => {
      const story = createStory(); const store = new FakeTextStore();
      const repository = new SaveRepository(store, story, new FixedClock());
      const good = rawSave(story, createInitialState(story));
      const invalid: string[] = ['{', '{}', 'null', '[]',
        good.replace('"trust":50', '"trust":"50"'),
        good.replace('"trust":50', '"trust":101'),
        good.replace('"remainingActions":18', '"remainingActions":-1'),
        good.replace('"remainingActions":18', '"remainingActions":1.5'),
        good.replace('"clueIds":[]', '"clueIds":["CL99"]'),
        good.replace('"flags":[]', '"flags":"shared"'),
        good.replace('"history":[]', '"history":[null]'),
        good.replace('"revision":0', '"revision":"0"'),
        good.replace('"currentNodeId":"N01"', '"currentNodeId":"MISSING"')];
      for (const raw of invalid) {
        store.files.set('save-auto.json', raw);
        const result = await repository.load('auto');
        expect(result.status).assertEqual('corrupt');
        expect(store.files.get('save-auto.json')).assertEqual(raw);
        expect(result.error.length > 0).assertTrue();
      }
    });

    it('T20_incompatible_versions_are_preserved', 0, async (): Promise<void> => {
      const rig = new ViewModelRig();
      const good = rawSave(rig.story, rig.vm.state);
      const versions: string[] = [good.replace('"schemaVersion":1', '"schemaVersion":2'),
        good.replace('"contentVersion":1', '"contentVersion":999')];
      for (const raw of versions) {
        rig.store.files.set('save-auto.json', raw);
        expect((await rig.repository.load('auto')).status).assertEqual('incompatible');
        expect(rig.store.files.get('save-auto.json')).assertEqual(raw);
      }
      expect(rig.store.writes.length).assertEqual(0);
    });

    it('T21_failed_persistence_does_not_commit_business_action', 0, async (): Promise<void> => {
      const rig = new ViewModelRig(); await rig.start();
      const original = JSON.stringify(rig.vm.state);
      const originalDisk = await rig.store.read('save-auto.json');
      rig.store.failKey = 'save-auto.json'; rig.store.failuresLeft = 1;
      await rig.choose('share');
      expect(JSON.stringify(rig.vm.state)).assertEqual(original);
      expect(await rig.store.read('save-auto.json')).assertEqual(originalDisk);
      expect(rig.vm.error).assertContain('未提交');
      expect(rig.vm.message.includes('已自动保存')).assertFalse();
      expect(rig.vm.busy).assertFalse();
      await rig.choose('share');
      expect(rig.vm.state.revision).assertEqual(1);
      expect(rig.vm.state.history.length).assertEqual(1);
      expect((await rig.repository.load('auto')).state.revision).assertEqual(1);
    });

    it('T22_startup_gate_prevents_overwriting_saved_progress', 0, async (): Promise<void> => {
      const rig = new ViewModelRig(); const played = cabinetRig();
      rig.store.files.set('save-auto.json', rawSave(rig.story, played.state));
      rig.store.holdReads();
      const initialization = rig.vm.initialize();
      await rig.vm.newGame(); await rig.vm.act(choiceAction(rig.vm.state, 'share'));
      expect(rig.vm.ready).assertFalse(); expect(rig.vm.busy).assertTrue();
      expect(rig.store.writes.length).assertEqual(0);
      rig.store.releaseReads(); await initialization;
      expect(rig.vm.ready).assertTrue();
      expect(JSON.stringify(rig.vm.state)).assertEqual(JSON.stringify(played.state));
      expect(rig.store.writes.length).assertEqual(0);
    });

    it('T23_all_endings_are_reachable_from_real_start', 0, (): void => {
      const full = completeEvidenceRig(); full.choose('submit');
      const partial = partialEvidenceRig(); partial.choose('submit');
      const exhausted = cabinetRig();
      for (let index: number = 0; index < 16; index++) { exhausted.solve('P01', '1111'); }
      const insufficient = insufficientEvidenceRig(); insufficient.choose('submit');
      expect(full.state.endingId).assertEqual('E01');
      expect(partial.state.endingId).assertEqual('E02');
      expect(exhausted.state.endingId).assertEqual('E03');
      expect(insufficient.state.endingId).assertEqual('E04');
      expect(exhausted.state.attempts[0].count).assertEqual(16);
      [full, partial, exhausted, insufficient].forEach((rig: TestRig): void => {
        expect(rig.state.history[0].fromNodeId).assertEqual('N01');
        expect(rig.state.history.length).assertEqual(rig.state.revision);
      });
    });

    it('T24_story_validation_rejects_duplicate_target_and_effect', 0, (): void => {
      const duplicated = createStory(); duplicated.nodes[1].id = duplicated.nodes[0].id;
      expect(validateStory(duplicated).ok).assertFalse();
      const badTarget = createStory(); badTarget.nodes[0].choices[0].targetNodeId = 'missing';
      expect(validateStory(badTarget).ok).assertFalse();
      const badEffect = createStory(); badEffect.nodes[0].choices[0].effects[0].kind = 'invented';
      expect(validateStory(badEffect).ok).assertFalse();
      const badCost = createStory(); badCost.nodes[0].choices[0].cost = -1;
      expect(validateStory(badCost).ok).assertFalse();
      let rejected: boolean = false;
      try { new GameEngine(badTarget); } catch (_) { rejected = true; }
      expect(rejected).assertTrue();
    });

    it('S25_serial_writes_keep_the_newest_snapshot', 0, async (): Promise<void> => {
      const rig = new ViewModelRig(); const played = new TestRig();
      const old = cloneState(played.state); played.choose('share');
      rig.store.holdWrites();
      const first = rig.repository.save('auto', old);
      const second = rig.repository.save('auto', played.state);
      expect(rig.store.writes.length).assertEqual(0);
      rig.store.releaseWrites();
      expect((await first).ok).assertTrue(); expect((await second).ok).assertTrue();
      expect((await rig.repository.load('auto')).state.revision).assertEqual(1);
      expect(rig.store.writes.join(',')).assertEqual('save-auto.json,save-auto.json.bak,save-auto.json');
    });

    it('S26_explicit_backup_recovery_and_tombstone', 0, async (): Promise<void> => {
      const rig = new ViewModelRig(); await rig.start(); await rig.choose('share');
      rig.store.files.set('save-auto.json', '{broken');
      const damaged = await rig.repository.load('auto');
      expect(damaged.status).assertEqual('corrupt'); expect(damaged.recoverable).assertTrue();
      const recovered = await rig.repository.load('auto', true);
      expect(recovered.status).assertEqual('valid'); expect(recovered.state.revision).assertEqual(0);
      expect(rig.store.files.get('save-auto.json')).assertEqual('{broken');
      expect((await rig.repository.deleteSlot('auto')).ok).assertTrue();
      const deleted = await rig.repository.load('auto', true);
      expect(deleted.status).assertEqual('empty'); expect(deleted.recoverable).assertFalse();
    });

    it('S27_manual_load_and_delete_preserve_other_slots', 0, async (): Promise<void> => {
      const rig = new ViewModelRig(); await rig.start(); await rig.choose('share');
      await rig.vm.saveManual('1', false); await rig.vm.saveManual('2', false);
      await rig.choose('take-note');
      expect(rig.vm.state.revision).assertEqual(2);
      await rig.vm.loadSlot('1');
      expect(rig.vm.state.revision).assertEqual(1);
      expect(rig.vm.state.trust).assertEqual(60);
      expect(rig.vm.state.remainingActions).assertEqual(17);
      expect((await rig.repository.load('auto')).state.revision).assertEqual(1);
      await rig.vm.deleteSlot('1');
      expect((await rig.repository.load('1')).status).assertEqual('empty');
      expect((await rig.repository.load('2')).state.revision).assertEqual(1);
      expect((await rig.repository.load('auto')).state.revision).assertEqual(1);
    });

    it('S28_interrupted_profile_write_reconciles_without_duplicates', 0, async (): Promise<void> => {
      const rig = new ViewModelRig(); const ending = completeEvidenceRig(); ending.choose('submit');
      await rig.repository.save('auto', ending.state);
      rig.store.failKey = 'profile.json'; rig.store.failuresLeft = 1;
      await rig.vm.initialize();
      expect(rig.vm.ready).assertFalse();
      expect((await rig.repository.load('auto')).state.endingId).assertEqual('E01');
      await rig.vm.initialize();
      expect(rig.vm.ready).assertTrue();
      expect(rig.vm.profile.unlockedEndingIds.join(',')).assertEqual('E01');
      await rig.vm.initialize();
      expect(rig.vm.profile.unlockedEndingIds.join(',')).assertEqual('E01');
    });

    it('S29_profile_backup_and_validation', 0, async (): Promise<void> => {
      const rig = new ViewModelRig(); const profile = new Profile();
      profile.unlockedEndingIds = ['E01'];
      expect((await rig.repository.saveProfile(profile)).ok).assertTrue();
      profile.largeText = true; await rig.repository.saveProfile(profile);
      rig.store.files.set('profile.json', '{bad');
      const recovered = await rig.repository.loadProfile();
      expect(recovered.ok).assertTrue();
      expect(recovered.profile.unlockedEndingIds.join(',')).assertEqual('E01');
      expect(recovered.profile.largeText).assertFalse();
      profile.unlockedEndingIds = ['E01', 'E01'];
      expect((await rig.repository.saveProfile(profile)).ok).assertFalse();
    });

    it('S30_condition_all_any_and_unknown_fail_closed', 0, (): void => {
      const state = createInitialState(createStory());
      const group: ConditionGroup = { all: [{ kind: 'actions', key: '', value: 1 }],
        any: [{ kind: 'trust', key: '', value: 60 }, { kind: 'clue', key: 'CL04', value: 0 }] };
      expect(evaluateConditions(group, state).ok).assertFalse();
      state.clueIds.push('CL04'); expect(evaluateConditions(group, state).ok).assertTrue();
      state.remainingActions = 0; expect(evaluateConditions(group, state).ok).assertFalse();
      state.remainingActions = 18;
      group.any.push({ kind: 'unknown', key: '', value: 0 });
      expect(evaluateConditions(group, state).ok).assertFalse();
    });

    it('S31_two_branches_change_available_actions', 0, (): void => {
      const high = new TestRig(); high.choices(['share', 'skip-note', 'skip-cabinet']);
      const low = new TestRig(); low.choices(['accuse', 'skip-note', 'skip-cabinet']);
      expect(high.engine.getAvailableChoices(high.state)[0].enabled).assertTrue();
      expect(low.engine.getAvailableChoices(low.state)[0].enabled).assertFalse();
      high.choices(['work-alone', 'alone-to-hub']); low.choices(['work-alone', 'alone-to-hub']);
      expect(high.engine.getAvailableChoices(high.state)[2].enabled).assertTrue();
      expect(low.engine.getAvailableChoices(low.state)[2].enabled).assertFalse();
      low.choices(['take-gateway', 'gateway-back']);
      expect(low.engine.getAvailableChoices(low.state)[2].enabled).assertTrue();
    });

    it('S32_invalid_timeline_input_does_not_change_state', 0, (): void => {
      const rig = completeEvidenceRig();
      // The successful route is kept separate; use a genuine unsolved timeline route here.
      const unsolved = cabinetRig(); unsolved.solve('P01', '0417');
      unsolved.choices(['work-alone', 'alone-to-hub', 'take-calibration', 'calibration-back',
        'take-gateway', 'gateway-back', 'open-timeline']);
      const before = JSON.stringify(unsolved.state);
      ['24:00', '00:60', '0:00', '', ' 00:00'].forEach((answer: string): void => {
        expect(unsolved.engine.dispatch(unsolved.state, puzzleAction(unsolved.state, 'P02', answer, 'task-first')).ok).assertFalse();
        expect(JSON.stringify(unsolved.state)).assertEqual(before);
      });
      expect(unsolved.engine.dispatch(unsolved.state, puzzleAction(unsolved.state, 'P02', '00:00', 'position-0')).ok).assertFalse();
      expect(rig.state.solvedPuzzleIds.includes('P02')).assertTrue();
    });

    it('S33_read_failure_is_explicit_and_preserves_storage', 0, async (): Promise<void> => {
      const rig = new ViewModelRig(); await rig.start();
      const before = await rig.store.read('save-auto.json'); rig.store.failReads = true;
      expect((await rig.repository.load('auto')).status).assertEqual('error');
      const freshVm = new GameViewModel(rig.story, rig.repository); await freshVm.initialize();
      expect(freshVm.ready).assertFalse();
      await freshVm.newGame();
      rig.store.failReads = false;
      expect(await rig.store.read('save-auto.json')).assertEqual(before);
    });

    it('S34_backup_write_failure_keeps_confirmed_primary', 0, async (): Promise<void> => {
      const rig = new ViewModelRig(); await rig.start();
      const before = await rig.store.read('save-auto.json');
      rig.store.failKey = 'save-auto.json.bak'; rig.store.failuresLeft = 1;
      await rig.choose('share');
      expect(rig.vm.state.revision).assertEqual(0);
      expect(await rig.store.read('save-auto.json')).assertEqual(before);
      expect(rig.vm.error.length > 0).assertTrue();
    });

    it('S35_explicit_stop_and_ending_read_only', 0, (): void => {
      const rig = completeEvidenceRig(); rig.choose('stop');
      expect(rig.state.endingId).assertEqual('E04');
      expect(explainEnding(rig.state).join(' ')).assertContain('主动结束');
      expect(rig.engine.getAvailableChoices(rig.state).length).assertEqual(0);
      const before = JSON.stringify(rig.state);
      expect(rig.engine.dispatch(rig.state, puzzleAction(rig.state, 'P02', '00:00', 'task-first')).ok).assertFalse();
      expect(JSON.stringify(rig.state)).assertEqual(before);
    });

    it('S36_history_validation_and_full_route_storage_size', 0, async (): Promise<void> => {
      const rig = new ViewModelRig();
      const full = completeEvidenceRig(); full.choose('submit');
      expect(validateState(full.state, full.story)).assertEqual('');
      expect((await rig.repository.save('auto', full.state)).ok).assertTrue();
      const raw = await rig.store.read('save-auto.json');
      let utf8Bytes: number = 0;
      for (let index: number = 0; index < raw.length; index++) {
        const code = raw.charCodeAt(index);
        if (code < 128) { utf8Bytes++; }
        else if (code < 2048) { utf8Bytes += 2; }
        else if (code >= 0xD800 && code <= 0xDBFF) { utf8Bytes += 4; index++; }
        else { utf8Bytes += 3; }
      }
      console.info('ZEROECHO_SAVE_SIZE E01 revision=' + full.state.revision + ' chars=' + raw.length + ' utf8Bytes=' + utf8Bytes);
      expect(utf8Bytes > raw.length).assertTrue();
      expect(utf8Bytes < 1048576).assertTrue();
      const changed = cloneState(full.state);
      changed.history[0].trustDelta = 0;
      expect(validateState(changed, full.story).length > 0).assertTrue();
      const counterfeit = createInitialState(full.story);
      counterfeit.clueIds.push('CL05');
      expect(validateState(counterfeit, full.story).length > 0).assertTrue();
      expect((await rig.repository.save('1', counterfeit)).ok).assertFalse();
      expect((await rig.repository.load('1')).status).assertEqual('empty');
    });

    it('S37_reset_clears_primary_and_backup_without_resurrection', 0, async (): Promise<void> => {
      const rig = new ViewModelRig();
      const full = completeEvidenceRig(); full.choose('submit');
      await rig.repository.save('auto', full.state);
      await rig.vm.initialize();
      await rig.vm.saveManual('1', false); await rig.vm.saveManual('2', false); await rig.vm.saveManual('3', false);
      await rig.vm.setLargeText(true);
      await rig.vm.resetAll();
      expect(rig.vm.ready).assertTrue(); expect(rig.vm.hasGame).assertFalse();
      expect(rig.vm.profile.unlockedEndingIds.length).assertEqual(0);
      expect(rig.vm.profile.largeText).assertFalse();
      for (const slot of ['auto', '1', '2', '3']) {
        expect((await rig.repository.load(slot, true)).status).assertEqual('empty');
        rig.store.files.set('save-' + slot + '.json', '{damaged-after-reset');
        expect((await rig.repository.load(slot, true)).recoverable).assertFalse();
      }
      rig.store.files.set('profile.json', '{damaged-after-reset');
      const profile = await rig.repository.loadProfile();
      expect(profile.ok).assertTrue();
      expect(profile.profile.unlockedEndingIds.length).assertEqual(0);
      expect(profile.profile.largeText).assertFalse();
    });

    it('S38_failed_manual_load_keeps_displayed_and_saved_progress', 0, async (): Promise<void> => {
      const rig = new ViewModelRig(); await rig.start(); await rig.choose('share');
      await rig.vm.saveManual('1', false); await rig.choose('take-note');
      const before = JSON.stringify(rig.vm.state);
      rig.store.failKey = 'save-auto.json'; rig.store.failuresLeft = 1;
      await rig.vm.loadSlot('1');
      expect(JSON.stringify(rig.vm.state)).assertEqual(before);
      expect(JSON.stringify((await rig.repository.load('auto')).state)).assertEqual(before);
      expect(rig.vm.error.length > 0).assertTrue();
      await rig.vm.loadSlot('1');
      expect(rig.vm.state.revision).assertEqual(1);
      expect(rig.vm.state.history.length).assertEqual(1);
    });

    it('S39_empty_primary_keeps_valid_save_backup_recoverable', 0, async (): Promise<void> => {
      const rig = new ViewModelRig(); await rig.start(); await rig.choose('share');
      rig.store.files.set('save-auto.json', '');
      const missing = await rig.repository.load('auto');
      expect(missing.status).assertEqual('corrupt');
      expect(missing.recoverable).assertTrue();
      expect(missing.error.length > 0).assertTrue();
      const recovered = await rig.repository.load('auto', true);
      expect(recovered.status).assertEqual('valid');
      expect(recovered.state.currentNodeId).assertEqual('N01');
      expect(recovered.state.revision).assertEqual(0);
      expect(await rig.store.read('save-auto.json')).assertEqual('');
    });

    it('S40_empty_profile_primary_uses_valid_backup', 0, async (): Promise<void> => {
      const rig = new ViewModelRig(); const profile = new Profile();
      profile.unlockedEndingIds = ['E02'];
      await rig.repository.saveProfile(profile);
      profile.largeText = true; await rig.repository.saveProfile(profile);
      rig.store.files.set('profile.json', '');
      const recovered = await rig.repository.loadProfile();
      expect(recovered.ok).assertTrue();
      expect(recovered.profile.unlockedEndingIds.join(',')).assertEqual('E02');
      expect(recovered.profile.largeText).assertFalse();
      expect(recovered.error.length > 0).assertTrue();
      expect(await rig.store.read('profile.json')).assertEqual('');
    });

    it('S41_primary_read_exception_allows_explicit_backup_recovery', 0, async (): Promise<void> => {
      const rig = new ViewModelRig(); await rig.start(); await rig.choose('share');
      const original = rig.store.files.get('save-auto.json');
      rig.store.failReadKey = 'save-auto.json';
      const failed = await rig.repository.load('auto');
      expect(failed.status).assertEqual('corrupt');
      expect(failed.recoverable).assertTrue();
      expect((await rig.repository.save('auto', createInitialState(rig.story))).ok).assertFalse();
      expect(rig.store.files.get('save-auto.json')).assertEqual(original);
      await rig.vm.initialize();
      expect(rig.vm.ready).assertTrue(); expect(rig.vm.hasGame).assertFalse();
      await rig.vm.loadSlot('auto', true);
      expect(rig.vm.hasGame).assertTrue();
      expect(rig.vm.state.revision).assertEqual(0);
      expect(rig.vm.message).assertContain('恢复有效副本');
      rig.store.failReadKey = '';
      const recovered = await rig.repository.load('auto');
      expect(recovered.status).assertEqual('valid');
      expect(recovered.state.revision).assertEqual(0);
    });

    it('S42_profile_read_exception_repaired_by_initialize', 0, async (): Promise<void> => {
      const rig = new ViewModelRig(); const profile = new Profile();
      profile.unlockedEndingIds = ['E02'];
      await rig.repository.saveProfile(profile);
      profile.largeText = true; await rig.repository.saveProfile(profile);
      const original = rig.store.files.get('profile.json');
      rig.store.failReadKey = 'profile.json';
      const recovered = await rig.repository.loadProfile();
      expect(recovered.ok).assertTrue();
      expect(recovered.profile.unlockedEndingIds.join(',')).assertEqual('E02');
      expect(recovered.profile.largeText).assertFalse();
      expect((await rig.repository.saveProfile(recovered.profile)).ok).assertFalse();
      expect(rig.store.files.get('profile.json')).assertEqual(original);
      await rig.vm.initialize();
      expect(rig.vm.ready).assertTrue();
      expect(rig.vm.profile.unlockedEndingIds.join(',')).assertEqual('E02');
      expect(rig.vm.profile.largeText).assertFalse();
      rig.store.failReadKey = '';
      const repaired = await rig.repository.loadProfile();
      expect(repaired.ok).assertTrue();
      expect(repaired.error).assertEqual('');
      expect(repaired.profile.unlockedEndingIds.join(',')).assertEqual('E02');
      expect(repaired.profile.largeText).assertFalse();
    });

    it('S43_invalid_profile_backup_does_not_initialize_as_empty', 0, async (): Promise<void> => {
      const rig = new ViewModelRig();
      rig.store.files.set('profile.json', '');
      rig.store.files.set('profile.json.bak', '{corrupt-backup');
      expect((await rig.repository.loadProfile()).ok).assertFalse();
      await rig.vm.initialize();
      expect(rig.vm.ready).assertFalse();
      await rig.vm.newGame();
      expect(rig.store.writes.length).assertEqual(0);
      expect(rig.store.files.get('profile.json.bak')).assertEqual('{corrupt-backup');
    });

    it('S44_confirmed_new_game_and_manual_overwrite_replace_unreadable', 0, async (): Promise<void> => {
      const rig = new ViewModelRig(); await rig.start(); await rig.choose('share');
      await rig.vm.saveManual('1', false);
      rig.store.failReadKey = 'save-auto.json';
      await rig.vm.newGame();
      expect(rig.vm.state.currentNodeId).assertEqual('N01');
      expect(rig.vm.state.revision).assertEqual(0);
      rig.store.failReadKey = '';
      expect((await rig.repository.load('auto')).state.revision).assertEqual(0);
      rig.store.failReadKey = 'save-1.json';
      const old = rig.store.files.get('save-1.json');
      await rig.vm.saveManual('1', false);
      expect(rig.vm.error).assertContain('确认覆盖');
      expect(rig.store.files.get('save-1.json')).assertEqual(old);
      await rig.vm.saveManual('1', true);
      expect(rig.vm.message).assertContain('已保存');
      rig.store.failReadKey = '';
      expect((await rig.repository.load('1')).state.revision).assertEqual(0);
    });
  });
}
